require 'net/http'
require 'oj'
require 'colorize'
require 'digest'

if ENV['OPENAI_API_KEY'].to_s.strip.empty?
  puts "Error: OPENAI_API_KEY environment variable is missing or empty.".colorize(:red)
  exit(1)
end

# Constants
OPENAI_API_ENDPOINT = "https://api.openai.com/v1/embeddings"
OPENAI_API_KEY = ENV['OPENAI_API_KEY']
HEADERS = {
  "Authorization" => "Bearer #{OPENAI_API_KEY}",
  "Content-Type" => "application/json"
}

CACHE_FILE = 'embeddings_cache.json'
CONFIG_HASH = Digest::SHA256.hexdigest(OPENAI_API_ENDPOINT + OPENAI_API_KEY)

def generate_embeddings(chunk)
  payload = {
    "model": "text-embedding-ada-002",
    "input": chunk
  }

  response = post_to_openai(payload)
  if response.code == "200"
    puts "Embedding generated successfully for chunk.".colorize(:green)
    Oj.load(response.body, symbol_keys: true)[:data].map { |data| data[:embedding] }
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
  request.body = Oj.dump(payload, mode: :compat)

  http.request(request)
end

def load_cache
  return {} unless File.exist?(CACHE_FILE)
  Oj.load_file(CACHE_FILE, symbol_keys: true)
end

def save_cache(cache)
  Oj.to_file(CACHE_FILE, cache, mode: :compat)
end

# Load the chunks from the previous script
chunks = Oj.load_file('code_chunks.json', symbol_keys: true)

# Load cache
cache = load_cache
puts "Loaded #{cache[:file_hashes].keys.count} file hashes from cache.".colorize(:blue)

# Check for configuration changes
if cache[:config_hash] != CONFIG_HASH
  cache = { config_hash: CONFIG_HASH, file_hashes: {} }
end

embeddings = []

chunks.each do |chunk|
  file_path = chunk[:metadata][:filepath] + '/' + chunk[:metadata][:filename]
  puts "Processing from line #{chunk[:metadata][:line_numbers].first} of #{file_path}...".colorize(:yellow)
  begin
    file_content = File.read(file_path)
    file_hash = Digest::SHA256.hexdigest(file_content)

    # Check if file has changed or is new
    # puts "Processing file: #{file_path}".colorize(:blue)
    # puts "Cached file hash: #{cache[:file_hashes][file_path]}".colorize(:gray)
    # puts "Current file hash: #{file_hash}".colorize(:gray)

    if cache[:file_hashes][file_path]
      puts "Found cached hash for file: #{file_path}".colorize(:green)
    else
      puts "No cached hash found for file: #{file_path}".colorize(:red)
    end
        
    if cache[:file_hashes][file_path] != file_hash
      embedding = generate_embeddings(chunk[:content])
      embeddings.concat(embedding) if embedding

      # Update cache
      cache[:file_hashes][file_path] = file_hash
      puts "Updated cache for file: #{file_path}".colorize(:green)
    end
  rescue => e
    puts "Error reading file #{file_path}. Error: #{e.message}".colorize(:red)
  end
end

# Create a set of all file paths from the chunks
file_paths_set = chunks.map { |c| c[:metadata][:filepath] + '/' + c[:metadata][:filename] }.to_set

# Remove entries for deleted files from the cache
cache[:file_hashes].keys.each do |cached_file_path|
  unless file_paths_set.include?(cached_file_path)
    cache[:file_hashes].delete(cached_file_path)
    puts "Removed #{cached_file_path} from cache.".colorize(:yellow)
  end
end

# Save updated cache
puts "Saving #{cache[:file_hashes].keys.count} file hashes to cache.".colorize(:blue)
save_cache(cache)

# Save the embeddings for the next step
Oj.to_file('embeddings.json', embeddings, mode: :compat) if embeddings.any?
