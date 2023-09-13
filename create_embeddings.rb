require 'oj'
require 'colorize'

def log_success(message)
  puts message.green
end

def log_error(message)
  puts message.red
end

# Load package statuses
status_file = 'packages_status.json'
if File.exist?(status_file)
  package_statuses = Oj.load(File.read(status_file))
else
  log_error("Packages status file not found. Please run update_repos.rb first.")
  exit
end

# Filter out the enabled packages
enabled_packages = package_statuses.select { |_package, status| status[:enabled] }

# Chunk the code from the enabled packages' local paths
code_chunks = []
files_processed = 0

enabled_packages.each do |package, details|
  path = details[:path]
  next unless File.directory?(path)

  # Read all .rb or .js files from the directory
  Dir["#{path}/**/*.{rb,js}"].each do |file|
    content = File.read(file)
    # Split the file content into chunks of 5000 characters (this is just an example size)
    chunks = content.scan(/.{1,5000}/m)
    code_chunks.concat(chunks)
    files_processed += 1
  end
end

# Logging for verification
log_success("Processed #{files_processed} files.")
log_success("Created #{code_chunks.size} code chunks.")
log_success("Sample chunk:\n#{code_chunks.sample[0..100]}...") # Displaying the first 100 characters of a random chunk

# TODO: Send the chunked code to the OpenAI embeddings API
# TODO: Obtain vector representations and upload to Pinecone
