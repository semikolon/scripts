require 'pinecone'

# Use the Pinecone API key from the system environment variable
PINECONE_API_KEY = ENV['PINECONE_API_KEY']
INDEX_NAME = "galaxybrain"
NAMESPACE = "code_embeddings"

# Initialize the Pinecone client
pinecone_client = Pinecone::Client.new(api_key: PINECONE_API_KEY)

def upload_to_pinecone(embeddings_data, client)
  index = pinecone_client.index(INDEX_NAME)

  embeddings_data.each do |key, item|
    begin
      index.upsert(
        namespace: NAMESPACE,
        id: key,
        vector: item[:embedding],
        metadata: item[:metadata]
      )
      puts "Successfully uploaded vector with ID #{key}"
    rescue => e
      puts "Error uploading vector with ID #{key}: #{e.message}"
    end
  end
end

# Load the embeddings data from the file
embeddings_file = "embeddings.json"
embeddings_data = Oj.load_file(embeddings_file, symbol_keys: true)

# Upload the embeddings to Pinecone
upload_to_pinecone(embeddings_data, pinecone_client)

# puts "Would have uploaded embeddings data:"
# puts Oj.dump(embeddings_data.to_a.sample(3).to_h, mode: :compat)

