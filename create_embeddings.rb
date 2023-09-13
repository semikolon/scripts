require 'oj'
require 'colorize'
require 'tiktoken_ruby'

# Constants
TOKEN_LIMIT = 8191
CHUNKS_FILE = 'code_chunks.json'
PACKAGE_STATUS_FILE = 'packages_status.json'

# Load package statuses
if File.exist?(PACKAGE_STATUS_FILE)
  package_statuses = Oj.load(File.read(PACKAGE_STATUS_FILE), symbol_keys: true)
else
  puts "Packages status file not found. Please run update_repos.rb first.".red
  exit
end

# Filter out the enabled packages
enabled_packages = package_statuses.select { |_package, details| details[:enabled] }

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

# Split the file content into chunks of 8191 tokens or less
def split_file_content_to_chunks(file, file_content, enc)
  chunks = []
  temp_chunk_content = ""
  temp_token_count = 0

  file_content_lines = file_content.split("\n")
  file_content_lines.each do |line|
      line_token_count = enc.encode(line).size
      if temp_token_count + line_token_count <= TOKEN_LIMIT
          temp_chunk_content += line + "\n"
          temp_token_count += line_token_count
      else
          chunks << { file_path: file, content: temp_chunk_content }
          temp_chunk_content = line + "\n"
          temp_token_count = line_token_count
      end
  end

  chunks << { file_path: file, content: temp_chunk_content } unless temp_chunk_content.empty?
  chunks
end

# Split the files into chunks - merging smaller ones together, splitting larger ones
def chunk_code(files)
  enc = Tiktoken.encoding_for_model("gpt-4")
  chunks = []
  current_chunk_content = ""
  current_token_count = 0
  last_file = nil

  files.each do |file|
      last_file = file
      file_content = read_file_content(file)
      file_token_count = enc.encode(file_content).size

      if file_token_count > TOKEN_LIMIT
          chunks.concat(split_file_content_to_chunks(file, file_content, enc))
      elsif current_token_count + file_token_count <= TOKEN_LIMIT
          current_chunk_content += file_content
          current_token_count += file_token_count
      else
          chunks << { file_path: file, content: current_chunk_content }
          current_chunk_content = file_content
          current_token_count = file_token_count
      end
  end

  chunks << { file_path: last_file, content: current_chunk_content } unless current_chunk_content.empty?
  chunks
end

# Collect files from the enabled packages' local paths
files_to_process = []
file_sizes = {}

# Iterate over each enabled package and collect its files
enabled_packages.each do |package_name, details|
  #log_success("Collecting files from package: #{package_name}")
  Dir["#{details[:path]}/**/*"].each do |file|
    next unless File.file?(file) && ['.rb', '.js', '.ts', '.jsx', '.tsx', '.md', '.html', '.css', '.scss'].include?(File.extname(file))
    files_to_process << file
    file_sizes[package_name] = file_sizes[package_name].to_i + File.stat(file).size
  end
end

code_chunks = chunk_code(files_to_process)

tiktoken_encoder = Tiktoken.encoding_for_model("gpt-4")

encoded_sizes = code_chunks.map { |chunk| tiktoken_encoder.encode(chunk[:content]).size }

# Display some statistics and a sample chunk
log_success("Processed #{files_to_process.length} files from #{enabled_packages.length} packages.")
log_success("Total token count: #{encoded_sizes.sum}")

average_token_count = encoded_sizes.empty? ? 0 : encoded_sizes.sum / encoded_sizes.length
log_success("Average token count per chunk: #{average_token_count}")

top_three_packages = file_sizes.sort_by { |_, size| -size }.first(3).map { |package, _| package }
log_success("Packages with the most content: #{top_three_packages}")

log_success("Created #{code_chunks.length} code chunks.")

if code_chunks.any?
  # Displaying the first 100 characters of a random chunk
  log_success("Sample chunk:\n#{code_chunks.sample[:content][0..100]}...")
else
  log_error("No code chunks were created.")
end

# Save the chunks to a JSON file
File.write('code_chunks.json', Oj.dump(code_chunks, mode: :compat))
