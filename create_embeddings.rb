require 'oj'
require 'colorize'
require 'tiktoken_ruby'
require 'pry'

PACKAGE_STATUS_FILE = 'packages_status.json'
CHUNKS_FILE = 'code_chunks.json'
CHUNK_SIZE = 300
OVERLAP_SIZE = 4 # lines of code, not tokens
TIKTOKEN_ENCODER = Tiktoken.encoding_for_model("gpt-4")

def log_success(message)
  puts message.green
end

def log_error(message)
  puts message.red
end

# Read the file content and ensure it is UTF-8 encoded
def read_file_content(file)
  file_content = File.read(file, encoding: 'UTF-8')
  unless file_content.valid_encoding?
      file_content = file_content.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
  end
  file_content
end

# Load package statuses
unless File.exist?(PACKAGE_STATUS_FILE)
  log_error("Packages status file not found. Please run update_repos.rb first.")
  exit
end
package_statuses = Oj.load_file(PACKAGE_STATUS_FILE, symbol_keys: true)

# Filter out the enabled packages
enabled_packages = package_statuses.select { |_package, details| details[:enabled] }

# Collect all files from enabled packages
files_to_process = []
file_sizes = {}

# Iterate over each enabled package and collect its files
enabled_packages.each do |package_name, details|
  Dir["#{details[:path]}/**/*"].each do |file|
    next unless File.file?(file) && ['.rb', '.js', '.ts', '.jsx', '.tsx', '.md', '.html', '.css', '.scss'].include?(File.extname(file))
    files_to_process << file
    file_sizes[package_name] = file_sizes[package_name].to_i + File.stat(file).size
  end
end

# # Log the number of tokens in the current chunk
# puts "Chunk from #{start_index} to #{end_index} has #{chunk_tokens.size} tokens."

# # Break the loop if we're at the end of the tokens
# break if end_index == tokens.size - 1


def split_into_chunks(content)
  return [] if content.nil?

  chunks = []
  lines = content.split("\n")
  line_index = 0
  buffer = []
  prev_buffer = nil

  while line_index < lines.size
    chunk_start_line = line_index + 1
    current_line_words = lines[line_index].split

    # Add lines to the buffer until we exceed CHUNK_SIZE
    while TIKTOKEN_ENCODER.encode((buffer + current_line_words).join(' ')).size <= CHUNK_SIZE && line_index < lines.size
      buffer += current_line_words
      line_index += 1
      current_line_words = lines[line_index].split if line_index < lines.size
    end

    # If buffer size exceeds CHUNK_SIZE, remove lines from the end until it fits
    while TIKTOKEN_ENCODER.encode(buffer.join(' ')).size > CHUNK_SIZE
      removed_line = buffer.pop.split
      line_index -= 1
    end

    chunk_end_line = line_index
    chunk = {
      content: buffer.join(' '),
      metadata: {
        line_numbers: (chunk_start_line..chunk_end_line).to_a
      }
    }
    chunks << chunk
    puts "Chunk created from line #{chunk_start_line} to #{chunk_end_line}." # Debugging

    # If the buffer hasn't changed, we're stuck in a loop, so break out
    if buffer == prev_buffer
      break
    end

    # Save the current buffer to compare in the next iteration
    prev_buffer = buffer.dup

    # Clear the buffer for the next chunk and backtrack by OVERLAP_SIZE for overlapping
    buffer.clear

    # If we've reached the end of the lines or the remaining content is smaller than the OVERLAP_SIZE, break out of the loop
    if line_index >= lines.size - 1 || (lines.size - line_index) <= OVERLAP_SIZE
      break
    end
    
    line_index = chunk_end_line - OVERLAP_SIZE
    line_index = [line_index, 0].max # Ensure it doesn't go negative
  end

  chunks
end


def generate_chunks_for_file(file_path)
  content = read_file_content(file_path)
  chunks = split_into_chunks(content)

  # Annotate each chunk with additional metadata
  chunks.map do |chunk|
    metadata = {
      filename: File.basename(file_path),
      filepath: File.dirname(file_path),
      line_numbers: chunk[:metadata][:line_numbers]
    }
    # Metadata should be fed to GPT-4 in the end, so it is included in :content to be part of the embedding
    {
      content: Oj.dump(metadata) + "\n" + chunk[:content],
      metadata: metadata
    }
  end
end

all_chunks = files_to_process.flat_map { |file_path| generate_chunks_for_file(file_path) }

# Display statistics  
encoded_sizes = all_chunks.map { |chunk| TIKTOKEN_ENCODER.encode(chunk[:content]).size }

# Display some statistics and a sample chunk
log_success("Processed #{files_to_process.length} files from #{enabled_packages.length} packages.")
log_success("Generated #{all_chunks.length} chunks.")
log_success("Total token count: #{encoded_sizes.sum}")

average_token_count = encoded_sizes.empty? ? 0 : encoded_sizes.sum / encoded_sizes.length
log_success("Average token count per chunk: #{average_token_count}")

top_three_packages = file_sizes.sort_by { |_, size| -size }.first(3).map { |package, _| package }
log_success("Packages with the most content: #{top_three_packages}")

if all_chunks.any?
  # Displaying the first 100 characters of a random chunk
  log_success("Sample chunk:\n#{all_chunks.sample[:content][0..100]}...")
else
  log_error("No code chunks were created.")
end

# Save the chunks to a JSON file
Oj.to_file(CHUNKS_FILE, all_chunks, mode: :compat)
