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
    send_data to_send
  end

  def add_square position, size, opts={}
    to_send = {
      message: 'add',
      shape: 'square',
      size: size,
      position: { x: position.x, y: position.y },
    }.merge(opts);
    return send_data to_send
  end

  def add_rectangle position, width, height, opts={}
    to_send = {
      message: 'add',
      shape: 'rectangle',
      width: width,
      height: height,
      position: { x: position.x, y: position.y },
    }.merge(opts)
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

  def list_details
    to_send = { message: 'list_details' }
    return send_data to_send
  end

  def push body_uuid, x, y
    to_send = {
      message: 'push',
      body_uuid: body_uuid,
      direction: { x: x, y: y }
    }
    return send_data to_send
  end

  def list_bodies
    to_send = { message: 'list_bodies' }
    return send_data to_send
  end

  def set_position body_uuid, position
    to_send = {
      message: 'set_position',
      body_uuid: body_uuid,
      position: { x: position.x, y: position.y }
    }
    return send_data to_send
  end

  def set_rotation body_uuid, rotation
    to_send = {
      message: 'set_rotation',
      body_uuid: body_uuid,
      rotation: rotation
    }
    return send_data to_send
  end

  def set_velocity body_uuid, x, y
    to_send = {
      message: 'set_velocity',
      body_uuid: body_uuid,
      velocity: { x: x, y: y }
    }
    return send_data to_send
  end

  def set_anti_gravity body_uuid
    to_send = {
      message: :set_anti_gravity,
      body_uuid: body_uuid
    }
    return send_data to_send
  end

  def set_color body_uuid, color
    to_send = {
      message: 'set_color',
      body_uuid: body_uuid,
      color: color
    }
    return send_data to_send
  end

  def destroy body_uuid
    to_send = {
      message: 'destroy',
      body_uuid: body_uuid
    }
    return send_data to_send
  end
end

class BatcherClient < Client

  def tick *args
    super *args
    send_batch
  end

  def send_data data
    (@pending ||= []) << data
  end

  def send_batch
    return if @pending.nil? || @pending.empty?
    to_send = { messages: @pending }
    r = send_data_orig to_send
    @pending.clear
    return r
  end

  def send_data_orig to_send
    self.socket.write(JSON.dump(to_send))
    self.socket.write("\n")
    self.socket.flush
    return JSON.parse(self.socket.gets())
  end
end

class Location
  attr_accessor :x, :y

  def initialize x: 0, y: 0
    self.x, self.y = x, y
  end

  def + loc
    self.class.new({ x: self.x + loc.x, y: self.y + loc.y })
  end

  def - loc
    self.class.new({ x: self.x - loc.x, y: self.y - loc.y })
  end

  def == other
    return false unless other.respond_to?(:x) && other.respond_to(:y)
    self.x == other.x && self.y == other.y
  end

  def distance_to other
    sum = 0
    sum += (x - other.x) ** 2
    sum += (y - other.y) ** 2
    Math.sqrt sum
  end

  def scaled_vector_to other, scale: 10
    vector = vector_to(other)
    Vector.new(x: vector.x * scale, y: vector.y * scale)
  end

  def vector_to other
    angle = angle_to other
    Vector.new(x: Math.cos(angle), y: Math.sin(angle))
  end

  def angle_to other
    offset = offset_of other
    Math.atan2(offset.y, offset.x)
  end

  def offset_of other
    other - self
  end

  def to_s
    "<#{self.class} #{x}:#{y}>"
  end
end

class Vector < Location
end
