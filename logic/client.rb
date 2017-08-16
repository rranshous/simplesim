require 'socket'
require 'json'

class Client

  attr_accessor :socket_path, :socket

  def initialize opts
    self.socket_path = opts[:socket_path]
  end

  def connect
    self.socket = UNIXSocket.new socket_path
  end

  def send_data to_send
    socket.write(JSON.dump(to_send))
    socket.write("\n")
    return JSON.parse(socket.gets())
  end

  def tick step_ms=1000/30
    to_send = {
      message: 'tick',
      step_ms: step_ms
    }
    puts "ticking: #{step_ms}"
    send_data to_send
  end

  def add_square position, size
    to_send = {
      message: 'add',
      shape: 'square',
      size: size,
      position: { x: position.x, y: position.y },
    };
    return send_data to_send
  end

  def set_gravity x, y
    to_send = {
      message: 'set_gravity',
      x: x, y: y
    }
    return send_data to_send
  end

  def detail opts
    body_uuid = opts[:body_uuid]
    to_send = { message: 'detail', body_uuid: body_uuid }
    return send_data to_send
  end

  def push
    to_send = {
      message: 'push',
      body_uuid: body_uuid,
      direction: { x: 1, y: 1 }
    }
    return send_data to_send
  end
end
