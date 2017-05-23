require 'Mysql2'
require 'sinatra'
require 'rufus-scheduler' # Module used to set timer to run the clean up method
require_relative "key_controller"

key_controller = Key_controller.new()

# Only run the following code when this file is the main file being run
# instead of having been required or loaded by another file
if __FILE__ == $0
  scheduler = Rufus::Scheduler.new
  scheduler.every '6000s' do
    key_controller.clean_keys
  end
end

# Root Endpoint
get '/' do
  "Welcome to the sinatra server"
end

# Endpoint to generate keys
get '/generate_keys' do
  keys_array = key_controller.generate_keys
  response = keys_array.join(", ")
end

# Endpoint to get an available key
get '/get_key' do
  response = key_controller.get_key
  if !response
    return "404, No keys available"
  end
  return response
end

# Endpoint to unblock a key
get '/unblock_key/:key' do |key|
  if key_controller.unblock_key(key)
    response = "Key successfully unblocked"
  else
    response = "No entry available with this key"
  end
end

# Endpoint to delete a key
get '/delete_key/:key' do |key|
  if key_controller.delete_key(key)
    response = "Key successfully deleted"
  else
    response = "No entry available with this key"
  end
end

# End point to keep the key alive. 
get '/keep_alive/:key' do |key|
  key_controller.keep_alive(key)
end


