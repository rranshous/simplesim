require 'socket'
require 'json'

class Client

  attr_accessor :socket_path, :socket, :tick_response

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
    self.tick_response = send_data to_send
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

  attr_accessor :tick_response

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
    self.tick_response = r.last
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

class VisClient < BatcherClient

  def set_viewport zoom_level: 1, viewport_leader_uuid: nil
    to_send = {
      message: 'set_viewport',
      zoom_level: zoom_level,
      viewport_leader_uuid: viewport_leader_uuid
    }
    return send_data to_send
  end

  def clicks
    tick_response_field(:clicks).each do |pos|
      Location.new(x: pos['x'], y: pos['y'])
    end
  end

  def keypresses
    tick_response_field(:keypresses)
  end

  def mouse_pos
    pos = tick_response_field(:mouse_pos, default: nil)
    if pos
      Location.new(x: pos['x'], y: pos['y'])
    else
      Location.new(x: 0, y: 0)
    end
  end

  private

  def tick_response_field field, default: []
    (self.tick_response || {})[field.to_s] || default
  end
end

class SimClient < Client
  def collisions
    tick_response_field(:collisions)
  end

  private

  def tick_response_field field, default: []
    (self.tick_response || {})[field.to_s] || default
  end
end

class Position
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
    return false unless other.respond_to?(:x) && other.respond_to?(:y)
    self.x == other.x && self.y == other.y
  end

  def to_s
    "<#{self.class} #{x}:#{y}>"
  end
end

class Location < Position

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
end

class Vector < Position
  def scale scalar
    Vector.new(x: self.x * scalar, y: self.y * scalar)
  end

  def * other
    if other.respond_to?(:x)
      self.class.new(x: self.x * other.x, y: self.y * other.y)
    else
      self.class.new(x: self.x * other, y: self.y * other)
    end
  end

  def < other
    self.x < other.x && self.y < other.y
  end

  def > other
    self.x > other.x && self.y > other.y
  end
end

class CappedVector < Vector
  attr_reader :max_x, :max_y

  def x= val
    if max_x
      @x = [val, max_x].min
      @x = [@x, -1 * max_x].max
    else
      @x = val
    end
  end

  def y= val
    if max_y
      @y = [val, max_y].min
      @y = [@y, -1 * max_y].max
    else
      @y = val
    end
  end

  def max_x= val
    @max_x = val
    self.x = self.x
  end

  def max_y= val
    @max_y = val
    self.y = self.y
  end

  def + other
    new_vector = super
    new_vector.max_x = self.max_x
    new_vector.max_y = self.max_y
    new_vector
  end

  def - other
    new_vector = super
    new_vector.max_x = self.max_x
    new_vector.max_y = self.max_y
    new_vector
  end

  def * other
    new_vector = super
    new_vector.max_x = self.max_x
    new_vector.max_y = self.max_y
    new_vector
  end
end
