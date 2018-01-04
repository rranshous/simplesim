require 'forwardable'

def log msg
  STDERR.write "#{msg}\n"
end

class Game

  FPS = 60
  MAX_TICK_MS = 30

  attr_accessor :vis_client, :sim_client, :last_tick_time, :last_step_time, :bodies

  def initialize
    self.bodies = []
    init_clients
    init_game
    init_attrs
  end

  def init_attrs
    # TO OVERRIDE
  end

  def init_clients
    self.sim_client = Client.new(socket_path: '/tmp/sim.sock')
    self.vis_client = Client.new(socket_path: '/tmp/vis.sock')
    self.sim_client.connect
    #self.vis_client.extend(Batcher)
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
    opts = { width: 10, height: 10, density: 0.1, static: false, friction: 0.1 }
    opts.merge!(kwargs)
    r = sim_client.add_rectangle(
      body.location, opts[:width], opts[:height],
      { density: opts[:density], friction: opts[:friction], static: opts[:static] }
    )
    puts 'adding rectangle'
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

  def draw_bodies
    bodies.each do |body|
      vis_client.set_position(body.uuid, body.location)
      vis_client.set_rotation(body.uuid, body.rotation)
    end
  end

  def push body: nil, vector: nil
    sim_client.push body.uuid, vector.x, vector.y
  end

  def consume food: nil
    if food
      foods.delete food
      remove_body body: food
    end
  end

  def set_rotation body: nil, rotation: nil
    sim_client.set_rotation body.uuid, rotation
  end

  def run &blk
    loop do
      blk.call(self.last_step_time || 0)
      tick
    end
  end
end


class Body
  extend Forwardable

  attr_accessor :location, :rotation, :uuid, :width, :height
  def_delegators :@location, :x, :y, :distance_to

  def initialize location: nil
    self.location = location
    init_attrs
  end

  def on? other
    # TODO: better
    distance_to(other) < [width, height].max + 1
  end

  def init_attrs
    # overwrite
  end

  def == other
    self.uuid == other.uuid
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
end
