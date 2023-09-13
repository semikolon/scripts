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

CACHE_FILE = 'cache.json'
CONFIG_HASH = Digest::SHA256.hexdigest(OPENAI_API_ENDPOINT + OPENAI_API_KEY)

def generate_embeddings(chunk)
  payload = {
    "model": "text-embedding-ada-002",
    "input": chunk
  }

  response = post_to_openai(payload)
  if response.code == "200"
    puts "Embedding generated successfully for chunk.".colorize(:green)
    JSON.parse(response.body)["data"].map { |data| data["embedding"] }
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

def load_cache
  return {} unless File.exist?(CACHE_FILE)
  Oj.load(File.read(CACHE_FILE), symbol_keys: true)
end

def save_cache(cache)
  File.write(CACHE_FILE, Oj.dump(cache, mode: :compat))
end

# Load the chunks from the previous script
chunks = Oj.load(File.read('code_chunks.json'), symbol_keys: true)

# Load cache
cache = load_cache

# Check for configuration changes
if cache[:config_hash] != CONFIG_HASH
  cache = { config_hash: CONFIG_HASH, file_hashes: {} }
end

embeddings = []

chunks.each do |chunk|
  file_path = chunk[:file_path]
  file_content = File.read(file_path)
  file_hash = Digest::SHA256.hexdigest(file_content)

  # Check if file has changed or is new
  if cache[:file_hashes][file_path] != file_hash
    embedding = generate_embeddings(chunk[:content])
    embeddings.concat(embedding) if embedding

    # Update cache
    cache[:file_hashes][file_path] = file_hash
  end
end

# Remove entries for deleted files from the cache
cache.keys.each do |cached_file_path|
  unless chunks.keys.include?(cached_file_path)
    cache.delete(cached_file_path)
    puts "Removed #{cached_file_path} from cache."
  end
end

# Save updated cache
save_cache(cache)

# Save the embeddings for the next step
File.write('embeddings.json', Oj.dump(embeddings, mode: :compat)) if embeddings.any?
