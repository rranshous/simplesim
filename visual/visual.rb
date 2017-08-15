require 'json'

require_relative '../logic/client.rb'

client = Client.new(socket_path: '/tmp/sim.sock')
client.connect

data = client.add_square OpenStruct.new(x: 10, y:10), 10
body_uuid = data['body_uuid']

puts "data: #{data}"
puts "body_uuid: #{body_uuid}"

data = client.detail({ body_uuid: body_uuid })
puts "data: #{data}"

client.tick

data = client.detail({ body_uuid: body_uuid })
puts "data: #{data}"
