require 'pinecone'
require 'concurrent'
require 'oj'

# Use the Pinecone API key from the system environment variable
PINECONE_API_KEY = ENV['PINECONE_API_KEY']
INDEX_NAME = "galaxybrain"
NAMESPACE = "code_embeddings"

# Initialize the Pinecone client
pinecone_client = Pinecone::Client.new(api_key: PINECONE_API_KEY)

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
        puts "Successfully uploaded vector with ID #{key}"
      rescue => e
        puts "Error uploading vector with ID #{key}: #{e.message}"
      end
    end
  end

  # Wait for all futures to complete
  futures.each(&:value)
end

# Load the embeddings data from the file
embeddings_file = "embeddings.json"
embeddings_data = Oj.load_file(embeddings_file, symbol_keys: true)

# Upload the embeddings to Pinecone
upload_to_pinecone(embeddings_data, pinecone_client)
