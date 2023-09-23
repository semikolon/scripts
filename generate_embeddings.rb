require 'net/http'
require 'oj'
require 'colorize'

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

# Load the chunks from the previous script
chunks = Oj.load_file('code_chunks.json', symbol_keys: true)

embeddings = {}

chunks.each do |chunk|
  file_path = chunk[:metadata][:filepath] + '/' + chunk[:metadata][:filename]
  start_line = chunk[:metadata][:line_numbers].first
  end_line = chunk[:metadata][:line_numbers].last
  key = "#{file_path}:#{start_line}-#{end_line}"

  puts "Processing from line #{start_line} to #{end_line} of #{file_path}...".colorize(:yellow)
  begin
    embedding = generate_embeddings(chunk[:content])
    embeddings[key] = embedding if embedding
  rescue => e
    puts "Error reading file #{file_path}. Error: #{e.message}".colorize(:red)
  end
end

# Save the embeddings for the next step
Oj.to_file('embeddings.json', embeddings, mode: :compat) if embeddings.any?
