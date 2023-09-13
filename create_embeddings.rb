
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
enabled_packages = package_statuses.select { |_package, status| status }

# TODO: Chunk the code from the enabled packages' local paths
# TODO: Send the chunked code to the OpenAI embeddings API
# TODO: Obtain vector representations and upload to Pinecone

log_success("Embeddings creation process completed!")
