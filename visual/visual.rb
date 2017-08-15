require 'socket'
require 'json'
require 'msgpack'

SOCKET_PATH = '/tmp/sim.sock'

socket = UNIXSocket.new SOCKET_PATH
body_uuid = ARGV.shift

tick = lambda {
  puts "-tick"
  # tick
  to_send = { message: 'tick' }
  puts "writing: #{to_send}"
  socket.write(JSON.dump(to_send))
  socket.write("\n")
  puts "written"

  # read back the response
  data = JSON.parse(socket.gets())
  puts "read: #{data}"
}

add_square = lambda {
  puts "-add-square"
  # send message to add square
  to_send = {
    message: 'add',
    shape: 'square',
    size: 10,
    position: { x: 10, y: 10 },
  };
  puts "writing: #{to_send}"
  socket.write(JSON.dump(to_send))
  socket.write("\n")
  puts "written"

  # read back the response
  data = JSON.parse(socket.gets())
  puts "read: #{data}"
  body_uuid = data['body_uuid']
}

detail = lambda {
  puts "-detail"
  # write message to get full body details
  to_send = {
    message: 'detail',
    body_uuid: body_uuid
  }
  puts "writing: #{to_send}"
  socket.write(JSON.dump(to_send))
  socket.write("\n")
  puts "written"

  # read back the response
  data = JSON.parse(socket.gets())
  puts "read: #{data}"
}

_push = lambda {
  puts "-push"
  # push the body
  to_send = {
    message: 'push',
    body_uuid: body_uuid,
    direction: { x: 1, y: 1 }
  }
  puts "writing: #{to_send}"
  socket.write(JSON.dump(to_send))
  socket.write("\n")
  puts "written"

  # read back the response
  data = JSON.parse(socket.gets())
  puts "read: #{data}"
}

if !body_uuid
  add_square.call
end
detail.call
tick.call
detail.call
tick.call
detail.call
tick.call
detail.call
