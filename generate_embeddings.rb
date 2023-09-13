require 'net/http'
require 'json'
require 'oj'
require 'colorize'
require 'awesome_print'

# Constants
OPENAI_API_ENDPOINT = "https://api.openai.com/v1/embeddings"
OPENAI_API_KEY = ENV['OPENAI_API_KEY']
HEADERS = {
  "Authorization" => "Bearer #{OPENAI_API_KEY}",
  "Content-Type" => "application/json"
}

def generate_embeddings(chunk)
  payload = {
    "model": "text-embedding-ada-002",
    "input": chunk
  }

  response = post_to_openai(payload)
  if response.code == "200"
    puts "Embedding generated successfully for chunk.".colorize(:green)
    JSON.parse(response.body)["data"].first["embedding"]
  else
    puts "Failed to generate embedding for chunk. Error: #{response.body}".colorize(:red)
    nil
  end
end

def post_to_openai(payload)
  uri = URI(OPENAI_API_ENDPOINT)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(uri.path, HEADERS)
  request.body = payload.to_json

  http.request(request)
end

# Load the chunks from the previous script
chunks = Oj.load(File.read('code_chunks.json'), symbol_keys: true)

# Only use the first chunk for now
first_chunk = chunks.first

embedding = generate_embeddings(first_chunk)

# Save the embedding for the next step (if successful)
File.write('embedding.json', Oj.dump(embedding, mode: :compat)) if embedding
