class BodyMover
  extend Forwardable

  attr_accessor :board

  def_delegators :@board, :set_velocity

  def set_rotation body: nil, rotation: nil
    board.set_rotation body.uuid, rotation
  end

  def update_rotation body: nil
    set_rotation body: body, rotation: body.rotation
  end

  def set_position body: nil, position: nil
    board.set_position(body.uuid, position)
  end

  def update_position body: nil
    set_position body: body, position: body.location
  end

  def update_velocity body: nil
    set_velocity body: body, vector: body.velocity
  end

  def push body: nil, direction: nil, vector: nil
    vector ||= body.send(direction)
    body.velocity += vector * (body.acceleration || 1)
    update_velocity body: body
  end

  def turn_to body: nil, rotation: nil
    body.rotation = rotation
    update_rotation body: body
  end

  def turn_toward body: nil, target: nil
    turn_to body: body, rotation: body.angle_to(target.location)
  end

  def go_to body: nil, position: nil
    body.location = position
    update_position body: body
  end

  def go_toward body: nil, target: nil
    push body: body, vector: body.vector_to(target.location)
  end
end

class Body
  extend Forwardable

  attr_accessor :location, :rotation, :uuid, :width, :height,
                :velocity, :color, :density, :static
  def_delegators :@location, :x, :y,
                             :distance_to, :angle_to, :vector_to

  def initialize location: nil, **kwargs
    self.location = location
    self.rotation = 0
    self.velocity = Vector.new(x: 0, y:0)
    kwargs.each do |k, v|
      wk = "#{k}="
      if self.respond_to? wk
        self.send(wk, v)
      end
    end
    init_attrs
  end

  def on? other
    # TODO: better
    return false if width.nil? && height.nil?
    distance_to(other) < [width, height].max + 5
  end

  def init_attrs
    # overwrite
  end

  def == other
    self.uuid == other.uuid
  end

  def above distance: 1
    self.location + absolute_up(distance: distance)
  end

  def absolute_up distance: 1
    Vector.new(y: distance)
  end

  def below distance: 1
    self.location + absolute_down(distance: distance)
  end

  def absolute_down distance: 1
    Vector.new(y: -1 * distance)
  end

  def absolute_left distance: 1
    Vector.new(x: -1 * distance)
  end

  def absolute_right distance: 1
    Vector.new(x: distance)
  end

  def relative_location offset: Location.new
    x = self.x + offset.x
    y = self.y + offset.y
    cos = Math.cos(rotation)
    sin = Math.sin(rotation)
    x2 = x - self.x
    y2 = y - self.y
    xf = x2 * cos - y2 * sin + self.x
    yf = x2 * sin + y2 * cos + self.y
    Location.new(x: xf, y: yf)
  end

  def to_s
    "<#{self.class}##{uuid} #{x}:#{y}>"
  end
end

module Mover

  def velocity= other
    @velocity = CappedVector.new
    @velocity.max_x = max_speed
    @velocity.max_y = max_speed
    self.velocity.x = other.x
    self.velocity.y = other.y
    self.velocity
  end

  def max_speed= speed
    @max_speed = speed
  end

  def max_speed
    @max_speed
  end

  def acceleration= acceleration
    @acceleration = acceleration
  end

  def acceleration
    @acceleration
  end

  def ahead distance: 1
    relative_location offset: Location.new(x: distance)
  end

  def forward
    self.location.vector_to(ahead)
  end

  def behind distance: 1
    relative_location offset: Location.new(x: -1 * distance)
  end

  def backward
    self.location.vector_to(behind)
  end

  def left distance: 1
    relative_location offset: Location.new(y: distance)
  end

  def leftward
    self.location.vector_to(left)
  end

  def right distance: 1
    relative_location offset: Location.new(y: -1 * distance)
  end

  def rightward
    self.location.vector_to(right)
  end
end

class BodyCollection

  extend Forwardable
  include Enumerable

  def_delegators :@bodies, :length, :size

  def initialize
    @bodies = {}
  end

  def each
    @bodies.values.each do |v|
      yield v
    end
  end

  def << body
    @bodies[body.uuid] = body
  end

  def get uuid
    @bodies[uuid]
  end

  def delete body
    @bodies.delete body.uuid
  end

  def near target_location
    raise ArgumentError if target_location.nil?
    sort_by do |body|
      body.distance_to target_location
    end.first
  end

  def nearby target_location, max_distance: 10
    raise ArgumentError if target_location.nil?
    self
      .sort_by    { |b| b.distance_to(target_location) }
      .take_while { |b| b.distance_to(target_location) < max_distance }
  end
end

class BodyCollectionLookup
  include Enumerable

  attr_accessor :collections

  def initialize
    self.collections = {}
  end

  def add_body body: nil, type: nil
    collection(type: type) << body
  end

  def collection type: nil
    self.collections[type] ||= BodyCollection.new
  end

  def get uuid: nil
    collections.values.each do |collection|
      body = collection.get uuid
      if body
        return body
      end
    end
    raise 'body miss'
    return nil
  end

  def each
    @collections.values.map(&:to_a).flatten.uniq.each do |body|
      yield body
    end
  end
end
