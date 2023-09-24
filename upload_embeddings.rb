require 'pinecone'
require 'concurrent'
require 'oj'

EMBEDDINGS_FILE ||= '.galaxybrain/code_embeddings.json'

# Use the Pinecone API key from the system environment variable
PINECONE_API_KEY = ENV['PINECONE_API_KEY']
PINECONE_ENVIRONMENT = ENV['PINECONE_ENVIRONMENT'] || 'gcp-starter'
INDEX_NAME = "galaxybrain"
NAMESPACE = "code_embeddings"

Pinecone.configure do |config|
  config.api_key = PINECONE_API_KEY
  config.environment = PINECONE_ENVIRONMENT
end

# Initialize the Pinecone client
pinecone_client = Pinecone::Client.new

def upload_to_pinecone(embeddings_data, client)
  index = client.index(INDEX_NAME)
  pool = Concurrent::FixedThreadPool.new(10) # Adjust the number based on your needs

  futures = embeddings_data.map do |key, item|
    Concurrent::Future.execute(executor: pool) do
      begin
        index.upsert(
          namespace: NAMESPACE,
          id: key,
          values: item[:embedding],
          metadata: item[:metadata]
        )
        puts "Successfully uploaded vector with ID #{key}".green
      rescue => e
        puts "Error uploading vector with ID #{key}: #{e.message}".red
      end
    end
  end

  # Wait for all futures to complete
  futures.each(&:value)
end

# Load the embeddings data from the file
embeddings_data = Oj.load_file(EMBEDDINGS_FILE, symbol_keys: true)

# TODO Validate the structure of embeddings data

if embeddings_data
  # Upload the embeddings to Pinecone
  values = upload_to_pinecone(embeddings_data, pinecone_client)
  puts "Successfully uploaded #{values.size} vectors to Pinecone".green
else
  puts "No embeddings data found, so can't upload.".red
end