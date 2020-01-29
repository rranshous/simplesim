require 'forwardable'

def log msg
  STDERR.write "#{msg}\n"
end

class Game
  extend Forwardable

  FPS = 60
  MAX_TICK_MS = 25

  attr_accessor :vis_client, :sim_client, :last_tick_time, :last_step_time,
                :bodies, :clicks, :keypresses

  def_delegators :@vis_client, :clicks, :keypresses, :mouse_pos

  def initialize
    self.bodies = BodyCollection.new
    init_clients
    init_game
    init_attrs
  end

  def init_attrs
    # TO OVERRIDE
  end

  def init_clients
    self.sim_client = SimClient.new(socket_path: '/tmp/sim.sock')
    self.vis_client = VisClient.new(socket_path: '/tmp/vis.sock')
    self.sim_client.connect
    self.vis_client.connect
  end

  def init_game
    self.sim_client.set_gravity(0, 0)
  end

  def tick
    diff_ms = (Time.now.to_f - last_tick_time.to_f) * 1000
    step_ms = [diff_ms, MAX_TICK_MS].min
    sim_client.tick step_ms
    vis_client.tick step_ms
    self.last_step_time = step_ms
    self.last_tick_time = Time.now
  end

  def add_bodies **kwargs
    bodies = kwargs.delete :bodies
    bodies.each { |body| add_body body: body, **kwargs }
  end

  def add_body body: nil, **kwargs
    opts = { width: body.width || 10, height: body.height || 10,
             density: 0.1, static: false,
             friction: 0.01, frictionAir: 0.01, frictionStatic: 0.5 }
    opts.merge!(kwargs)
    r = sim_client.add_rectangle(
      body.location, opts[:width], opts[:height],
      { density: opts[:density], friction: opts[:friction],
        frictionAir: opts[:frictionAir], static: opts[:static],
        frictionStatic: opts[:frictionStatic]}
    )
    vis_client.add_rectangle(
      body.location, opts[:width], opts[:height],
      { body_uuid: r['body_uuid'] }.merge(opts)
    )
    body.uuid = r['body_uuid']
    self.bodies << body
    return body
  end

  def remove_body body: nil
    vis_client.destroy body.uuid
    sim_client.destroy body.uuid
    bodies.delete body
  end

  def update_bodies
    sim_client.list_details.each do |details|
      body_uuid = details['body_uuid']
      body = bodies.find { |b| b.uuid == body_uuid } # TODO: dont scan
      next if body.nil?
      x, y = details['position']['x'], details['position']['y']
      loc = Location.new(x: x, y: y)
      body.location = loc
      body.rotation = details['rotation']
      body.width    = details['width']
      body.height   = details['height']
    end
  end

  def get_body uuid: nil
    search_body = Body.new
    search_body.uuid = uuid
    self.bodies.find(search_body)
  end

  def draw_bodies
    bodies.each do |body|
      vis_client.set_position(body.uuid, body.location)
      vis_client.set_rotation(body.uuid, body.rotation)
    end
  end

  def push body: nil, vector: nil, direction: nil
    if vector
      sim_client.push body.uuid, vector.x, vector.y
    elsif direction
      push body: body, vector: body.send(direction.to_sym).scale(100)
    end
  end

  def set_rotation body: nil, rotation: nil
    sim_client.set_rotation body.uuid, rotation
  end

  def set_position body: nil, position: nil
    sim_client.set_position(body.uuid, position)
  end

  def set_velocity body: nil, vector: nil
    sim_client.set_velocity(body.uuid, vector.x, vector.y)
  end

  def run &blk
    loop do
      blk.call(self.last_step_time || 0)
      tick
      update_bodies
      draw_bodies
    end
  end

  def collisions
    self.sim_client.collisions.map do |collision|
      collision['pair'].map do |uuid|
        self.get_body(uuid: uuid)
      end
    end
  end
end


class Body
  extend Forwardable

  attr_accessor :location, :rotation, :uuid, :width, :height
  def_delegators :@location, :x, :y,
                             :distance_to, :angle_to, :vector_to

  def initialize location: nil
    self.location = location
    self.rotation = 0
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

  def ahead distance: 100
    relative_location offset: Location.new(x: distance)
  end

  def forward
    self.location.vector_to(ahead)
  end

  def behind distance: 100
    relative_location offset: Location.new(x: -1 * distance)
  end

  def backward
    self.location.vector_to(behind)
  end

  def left distance: 100
    relative_location offset: Location.new(y: distance)
  end

  def leftward
    self.location.vector_to(left)
  end

  def right distance: 100
    relative_location offset: Location.new(y: -1 * distance)
  end

  def rightward
    self.location.vector_to(right)
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

class BodyCollection < Array
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

module RainbowGenerator
  def self.hex
    rainbow_colors = [
      '#9400D3', '#4B0082', '#0000FF',
      '#00FF00', '#FFFF00', '#FF7F00', '#FF0000'
    ]
    last_color = '#000000'
    rainbow_colors.map do |color|
      c = Gradient.new(step: 0.1, colors: [last_color, color]).hex
      last_color = color
      c
    end.flatten
  end
end
