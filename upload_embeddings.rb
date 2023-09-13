require 'net/http'
require 'uri'
require 'json'
require 'oj'

# Placeholder Pinecone API key
PINECONE_API_KEY = "YOUR_PINECONE_API_KEY"
PINECONE_ENDPOINT = "https://api.pinecone.io/v1/vectors"

def upload_to_pinecone(embeddings_data)
  uri = URI(PINECONE_ENDPOINT)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  # Set up the request headers
  headers = {
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{PINECONE_API_KEY}"
  }

  embeddings_data.each do |item|
    request = Net::HTTP::Post.new(uri, headers)
    request.body = Oj.dump({
      namespace: "code_embeddings",
      id: item['id'],
      vector: item['embedding'],
      metadata: item['metadata']
    }, mode: :compat)

    response = http.request(request)

    # Handle the response
    if response.code.to_i >= 400
      puts "Error uploading vector with ID #{item['id']}: #{response.body}"
    else
      puts "Successfully uploaded vector with ID #{item['id']}"
    end
  end
end

# Load the embeddings data from the file
embeddings_file = "embeddings.json"
embeddings_data = Oj.load(File.read(embeddings_file), symbol_keys: true)

# Upload the embeddings to Pinecone
upload_to_pinecone(embeddings_data)
