require 'pinecone'

# Use the Pinecone API key from the system environment variable
PINECONE_API_KEY = ENV['PINECONE_API_KEY']

# Initialize the Pinecone client
pinecone_client = Pinecone::Client.new(api_key: PINECONE_API_KEY)

def upload_to_pinecone(embeddings_data, client)
  embeddings_data.each do |item|
    begin
      client.upsert_item(
        namespace: "code_embeddings",
        id: item['id'],
        vector: item['embedding'],
        metadata: item['metadata']
      )
      puts "Successfully uploaded vector with ID #{item['id']}"
    rescue => e
      puts "Error uploading vector with ID #{item['id']}: #{e.message}"
    end
  end
end

# Load the embeddings data from the file
embeddings_file = "embeddings.json"
embeddings_data = Oj.load_file(embeddings_file, symbol_keys: true)

# Upload the embeddings to Pinecone
upload_to_pinecone(embeddings_data, pinecone_client)

