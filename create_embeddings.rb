require 'oj'
require 'colorize'

# Constants
TOKEN_LIMIT = 8191
CHUNKS_FILE = 'code_chunks.json'

def log_success(message)
  puts message.green
end

def log_error(message)
  puts message.red
end

# Load package statuses
PACKAGE_STATUS_FILE = 'packages_status.json'

if File.exist?(PACKAGE_STATUS_FILE)
  package_statuses = Oj.load(File.read(PACKAGE_STATUS_FILE), symbol_keys: true)
else
  log_error("Packages status file not found. Please run update_repos.rb first.")
  exit
end

# Filter out the enabled packages
enabled_packages = package_statuses.select { |_package, details| details[:enabled] }

def chunk_code(files)
  chunks = []
  current_chunk = ""
  current_tokens = 0

  files.each do |file|
    file_content = File.read(file)
    file_tokens = file_content.split.size  # Simple tokenization based on whitespace

    if current_tokens + file_tokens <= TOKEN_LIMIT
      current_chunk << file_content
      current_tokens += file_tokens
    else
      chunks << current_chunk
      current_chunk = file_content
      current_tokens = file_tokens
    end
  end
  chunks << current_chunk unless current_chunk.empty?

  return chunks
end

# Collect the code from the enabled packages' local paths
all_files = []

# Iterate over each enabled package and collect its files
enabled_packages.each do |package_name, details|
  log_success("Collecting files from package: #{package_name}")
  Dir["#{details[:path]}/**/*"].each do |file|
    next unless File.file?(file) && ['.rb', '.js', '.ts', '.jsx', '.tsx'].include?(File.extname(file))
    all_files << file
  end
end

# Chunk the collected files
code_chunks = chunk_code(all_files)

# Display some statistics and a sample chunk
log_success("Processed #{all_files.length} files.")
log_success("Created #{code_chunks.length} code chunks.")
if code_chunks.any?
  log_success("Sample chunk:\n#{code_chunks.sample[0..100]}...") # Displaying the first 100 characters of a random chunk
else
  log_error("No code chunks were created.")
end

# TODO: Send the chunked code to the OpenAI embeddings API
# TODO: Obtain vector representations and upload to Pinecone
