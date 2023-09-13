require 'oj'
require 'colorize'

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

def chunk_code(content)
  # Define a maximum chunk size. This can be adjusted based on requirements.
  max_chunk_size = 5000
  
  # Split the content into chunks of the defined size.
  chunks = content.scan(/.{1,#{max_chunk_size}}/m)
  
  return chunks
end

# Chunk the code from the enabled packages' local paths
code_chunks = []
file_count = 0

# Iterate over each enabled package and process its files
enabled_packages.each do |package_name, details|
  log_success("Processing package: #{package_name}")
  Dir["#{details[:path]}/**/*"].each do |file|
    puts "Identified file: #{file}" # Print the identified file
    next unless File.file?(file) && ['.rb', '.js', '.ts', '.jsx', '.tsx'].include?(File.extname(file))
    log_success("Processing file: #{file}")
    file_content = File.read(file)
    code_chunks.concat(chunk_code(file_content))
    file_count += 1
  end
end


# Display some statistics and a sample chunk
log_success("Processed #{file_count} files.")
log_success("Created #{code_chunks.length} code chunks.")
if code_chunks.any?
  log_success("Sample chunk:\n#{code_chunks.sample[0..100]}...") # Displaying the first 100 characters of a random chunk
else
  log_error("No code chunks were created.")
end

# TODO: Send the chunked code to the OpenAI embeddings API
# TODO: Obtain vector representations and upload to Pinecone
