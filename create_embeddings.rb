require 'oj'
require 'colorize'
require 'tiktoken_ruby'

# Constants
TOKEN_LIMIT = 300  
OVERLAP_SIZE = 30
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

# Split each file's content into semantic chunks of 300 tokens or less
def split_file_to_chunks(file, file_content)
  chunks = []
  tok = Tiktoken.encoding_for_model("gpt-4")
  temp_chunk_content = ""
  temp_token_count = 0

  file_content_lines = file_content.split("\n")
  file_content_lines.each do |line|
    line_token_count = tok.encode(line).size
    
    if temp_token_count + line_token_count <= TOKEN_LIMIT
      temp_chunk_content += line + "\n"
      temp_token_count += line_token_count
    else
      # Save last chunk
      last_chunk_content = temp_chunk_content

      # Take last OVERLAP_SIZE tokens 
      overlap_content = last_chunk_content[-OVERLAP_SIZE..-1]

      chunks << { file_path: file, content: last_chunk_content }
      temp_chunk_content = overlap_content + line + "\n"  
      temp_token_count = line_token_count   
    end
  end

  chunks << { file_path: file, content: temp_chunk_content } unless temp_chunk_content.empty?
  chunks
end

# Generate chunks for each file
def generate_chunks(files)
  chunks = []

  files.each do |file|
    file_content = read_file_content(file)
    chunks.concat(split_file_to_chunks(file, file_content))
  end

  chunks 
end

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

# Generate 300 token chunks
code_chunks = generate_chunks(files_to_process)

# Display statistics  
tiktoken_encoder = Tiktoken.encoding_for_model("gpt-4")

encoded_sizes = code_chunks.map { |chunk| tiktoken_encoder.encode(chunk[:content]).size }

# Display some statistics and a sample chunk
log_success("Processed #{files_to_process.length} files from #{enabled_packages.length} packages.")
log_success("Generated #{code_chunks.length} chunks.")
log_success("Total token count: #{encoded_sizes.sum}")

average_token_count = encoded_sizes.empty? ? 0 : encoded_sizes.sum / encoded_sizes.length
log_success("Average token count per chunk: #{average_token_count}")

top_three_packages = file_sizes.sort_by { |_, size| -size }.first(3).map { |package, _| package }
log_success("Packages with the most content: #{top_three_packages}")

if code_chunks.any?
  # Displaying the first 100 characters of a random chunk
  log_success("Sample chunk:\n#{code_chunks.sample[:content][0..100]}...")
else
  log_error("No code chunks were created.")
end

# Save the chunks to a JSON file
File.write('code_chunks.json', Oj.dump(code_chunks, mode: :compat))