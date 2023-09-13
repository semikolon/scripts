require 'oj'
require 'colorize'
require 'tiktoken_ruby'

# Constants
TOKEN_LIMIT = 8191
CHUNKS_FILE = 'code_chunks.json'
PACKAGE_STATUS_FILE = 'packages_status.json'

# Load package statuses
if File.exist?(PACKAGE_STATUS_FILE)
  package_statuses = Oj.load(File.read(PACKAGE_STATUS_FILE), symbol_keys: true)
else
  puts "Packages status file not found. Please run update_repos.rb first.".red
  exit
end

# Filter out the enabled packages
enabled_packages = package_statuses.select { |_package, details| details[:enabled] }

def log_success(message)
  puts message.green
end

def log_error(message)
  puts message.red
end

def chunk_code(files)
  enc = Tiktoken.encoding_for_model("gpt-4")
  chunks = []
  current_chunk = ""
  current_token_count = 0

  files.each do |file|
    file_content = File.read(file, encoding: 'UTF-8')
    
    # If the content is not valid UTF-8, try to fix it
    unless file_content.valid_encoding?
      file_content = file_content.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    end

    file_token_count = enc.encode(file_content).size

    # If the file's token count exceeds the token limit, split the file into multiple chunks
    if file_token_count > TOKEN_LIMIT
      file_content_lines = file_content.split("\n")
      temp_chunk = ""
      temp_token_count = 0

      file_content_lines.each do |line|
        line_token_count = enc.encode(line).size

        # If adding the line doesn't exceed the token limit, add it to the temp_chunk
        if temp_token_count + line_token_count <= TOKEN_LIMIT
          temp_chunk += line + "\n"
          temp_token_count += line_token_count
        else
          # If it exceeds, save the current temp_chunk and start a new one
          chunks << temp_chunk
          temp_chunk = line + "\n"
          temp_token_count = line_token_count
        end
      end

      # Add any remaining content of the temp_chunk
      chunks << temp_chunk unless temp_chunk.empty?
    elsif current_token_count + file_token_count <= TOKEN_LIMIT
      current_chunk += file_content
      current_token_count += file_token_count
    else
      chunks << current_chunk
      current_chunk = file_content
      current_token_count = file_token_count
    end
  end

  chunks << current_chunk unless current_chunk.empty?
  chunks
end

# Collect files from the enabled packages' local paths
files_to_process = []

# Iterate over each enabled package and collect its files
enabled_packages.each do |package_name, details|
  log_success("Collecting files from package: #{package_name}")
  Dir["#{details[:path]}/**/*"].each do |file|
    next unless File.file?(file) && ['.rb', '.js', '.ts', '.jsx', '.tsx', '.md', '.html', '.css', '.scss'].include?(File.extname(file))
    files_to_process << file
  end
end

# Chunk the code
code_chunks = chunk_code(files_to_process)

# Display some statistics and a sample chunk
log_success("Processed #{files_to_process.length} files.")
log_success("Created #{code_chunks.length} code chunks.")
if code_chunks.any?
  log_success("Sample chunk:\n#{code_chunks.sample[0..100]}...") # Displaying the first 100 characters of a random chunk
else
  log_error("No code chunks were created.")
end

# Save the chunks to a JSON file
File.write('code_chunks.json', Oj.dump(code_chunks, mode: :compat))
