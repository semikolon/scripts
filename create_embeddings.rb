require 'oj'
require 'colorize'
require 'tiktoken_ruby'
require 'digest'
require 'pry'

# PACKAGE_STATUS_FILE = 'packages_status.json'
CACHE_FILE = 'code_cache.json'
CHUNKS_FILE = 'code_chunks.json'
CHUNK_SIZE = 300
OVERLAP_SIZE = 4 # lines of code, not tokens
CONFIG_HASH = Digest::SHA256.hexdigest((CHUNK_SIZE + OVERLAP_SIZE).to_s)
TIKTOKEN_ENCODER = Tiktoken.encoding_for_model("gpt-4")

def log_success(message)
  puts message.green
end

def log_error(message)
  puts message.red
end

def load_cache
  return {} unless File.exist?(CACHE_FILE)
  Oj.load_file(CACHE_FILE)
end

def save_cache(cache)
  Oj.to_file(CACHE_FILE, cache, mode: :compat)
end

# Load cache
cache = load_cache
unless cache.nil? || cache.empty?
  puts "Loaded #{cache['file_hashes'].keys.count} file hashes from cache.".colorize(:blue)
else
  puts "No cache found.".colorize(:blue)
end

# Check for configuration changes
if cache['config_hash'] != CONFIG_HASH
  cache = { config_hash: CONFIG_HASH, file_hashes: {} }
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

def split_into_chunks(content)
  chunks = []
  lines = content.split("\n")
  line_index = 0

  # Use the informed guess of 50 lines as the starting chunk size
  # We previously scanned a lot of code and found each line of code roughly has 6.8 tokens.
  # 50 x 6.8 = 340 tokens. So we'll include 50 lines and adjust if it's too big or too small.
  estimated_chunk_size = 50

  while line_index < lines.size
    chunk_start_line = line_index
    chunk_lines = lines[line_index, estimated_chunk_size] || []

    while TIKTOKEN_ENCODER.encode(chunk_lines.join("\n")).size < CHUNK_SIZE && (line_index + chunk_lines.size) < lines.size
      chunk_lines << lines[line_index + chunk_lines.size]
    end

    while TIKTOKEN_ENCODER.encode(chunk_lines.join("\n")).size > CHUNK_SIZE + 100
      chunk_lines.pop
    end

    chunk_end_line = chunk_start_line + chunk_lines.size - 1
    chunk = {
      content: chunk_lines.join("\n"),
      metadata: {
        line_numbers: (chunk_start_line..chunk_end_line).map { |num| num + 1 }
      }
    }
    chunks << chunk
    
    # Check if chunk_lines is empty or if we're stuck in a loop
    if chunk_lines.empty? || line_index + chunk_lines.size - OVERLAP_SIZE == line_index
      break
    end

    line_index += chunk_lines.size - OVERLAP_SIZE
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

all_chunks = files_to_process.flat_map do |file_path|
  file_content = read_file_content(file_path)
  file_hash = Digest::SHA256.hexdigest(file_content)

  # Check if file has changed or is new
  # puts "Processing file: #{file_path}".colorize(:blue)
  # puts "Cached file hash: #{cache['file_hashes'][file_path]}".colorize(:gray)
  # puts "Current file hash: #{file_hash}".colorize(:gray)
  
  # if cache['file_hashes'][file_path]
  #   puts "Found cached hash for file: #{file_path}".colorize(:green)
  # else
  #   puts "No cached hash found for file: #{file_path}".colorize(:red)
  # end
  
  if cache['file_hashes'][file_path] != file_hash
    # puts "Cached hash does not match on-disk hash for file: #{file_path}".colorize(:red)
    # Generate chunks if file hash is different
    chunks = generate_chunks_for_file(file_path)
    
    # Update cache
    cache['file_hashes'][file_path] = file_hash
    puts "Generated chunks and updated cache for file: #{file_path}".colorize(:green)
    
    chunks  # Return the generated chunks
  else
    []  # Return an empty array if no new chunks are generated
  end
end


# Create a set of all file paths from the chunks
# file_paths_set = all_chunks.map { |c| c[:metadata][:filepath] + '/' + c[:metadata][:filename] }.to_set
file_paths_set = files_to_process.to_set
# TODO maybe these should come from files_to_process instead?

# Remove entries for deleted files from the cache
deleted_files = []
cache['file_hashes'].keys.each do |cached_file_path|
  unless file_paths_set.include?(cached_file_path)
    cache['file_hashes'].delete(cached_file_path)
    deleted_files << cached_file_path
  end
end
puts "Removed #{deleted_files.count} files from cache.".colorize(:yellow) if deleted_files.any?

# Save updated cache
puts "Saving #{cache['file_hashes'].keys.count} file hashes to cache.".colorize(:blue)
save_cache(cache)


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
  puts "No code chunks were created.".colorize(:yellow)
end

# Save the chunks to a JSON file
Oj.to_file(CHUNKS_FILE, all_chunks, mode: :compat)
