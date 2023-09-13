require 'net/http'
require 'json'
require 'oj'
require 'colorize'
require 'awesome_print'
require 'digest'

if ENV['OPENAI_API_KEY'].to_s.strip.empty?
  puts "Error: OPENAI_API_KEY environment variable is missing or empty."
  exit(1)
end

# Constants
OPENAI_API_ENDPOINT = "https://api.openai.com/v1/embeddings"
OPENAI_API_KEY = ENV['OPENAI_API_KEY']
HEADERS = {
  "Authorization" => "Bearer #{OPENAI_API_KEY}",
  "Content-Type" => "application/json"
}

# Load or initialize the cache
def load_cache
  if File.exist?('cache.json')
    Oj.load_file('cache.json', symbol_keys: true)
  else
    {}
  end
end

# Calculate file hash
def calculate_file_hash(file_path)
  Digest::SHA256.file(file_path).hexdigest
end

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
cache = load_cache

chunks.each do |file_path, chunk|
  current_hash = calculate_file_hash(file_path)

  # If the file is in the cache and the hash matches, skip processing
  if cache[file_path] && cache[file_path] == current_hash
    puts "Cache hit for #{file_path}. Skipping..."
    next
  else
    # Process the chunk and send for embeddings
    embedding = generate_embeddings(chunk)

    # Save the embedding for the next step (if successful)
    File.write('embedding.json', Oj.dump(embedding, mode: :compat)) if embedding

    # Update the cache with the new hash
    cache[file_path] = current_hash
  end
end

# Remove entries for deleted files from the cache
cache.keys.each do |cached_file_path|
  unless chunks.keys.include?(cached_file_path)
    cache.delete(cached_file_path)
    puts "Removed #{cached_file_path} from cache."
  end
end

# Save the updated cache to cache.json
Oj.to_file('cache.json', cache, mode: :compat)
