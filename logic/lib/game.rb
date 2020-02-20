require 'forwardable'
require_relative 'client'
require_relative 'body'

def log msg
  STDERR.write "#{msg}\n"
  STDERR.flush
end

def log_time(label)
  start = Time.now.to_f
  r = yield
  t = (Time.now.to_f - start) * 1000
  if t < 0.01
    t = "~0"
  end
  log "#{label}: #{t}"
  r
end

class Game
  extend Forwardable

  FPS = 30
  MAX_TICK_MS = 100

  attr_accessor :vis_client, :sim_client, :last_tick_time, :last_step_time,
                :bodies, :clicks, :keypresses,
                :tick_count, :body_mover

  def_delegators :@vis_client, :clicks, :keypresses, :mouse_pos
  def_delegators :@sim_client, :push, :set_rotation,
                               :set_position

  def initialize
    self.tick_count = 0
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
    self.tick_count += 1
  end

  def register_body body: nil, **kwargs
    opts = { width: body.width || 10, height: body.height || 10,
             density: body.density || 0.1, static: body.static || false,
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
    if body.color
      set_color body: body, color: body.color
    end
    if body.velocity
      set_velocity body: body, vector: body.velocity
    end
    return body
  end

  def remove_body body: nil
    vis_client.destroy body.uuid
    sim_client.destroy body.uuid
  end

  def update_bodies
    sim_client.list_details.each do |details|
      body_uuid = details['body_uuid']
      body = get_body(uuid: body_uuid)
      if body.nil?
        puts "body lookup miss"
        next
      end
      loc = Location.new x: details['position']['x'],
                         y: details['position']['y']
      velocity = Vector.new x: details['velocity']['x'],
                            y: details['velocity']['y']
      body.location = loc
      body.velocity = velocity
      body.rotation = details['rotation']
      body.width    = details['width']
      body.height   = details['height']
    end
  end

  def get_body uuid: nil
    bodies.get uuid: uuid
  end

  def draw_bodies
    bodies.each do |body|
      vis_client.set_position(body.uuid, body.location)
      vis_client.set_rotation(body.uuid, body.rotation)
    end
  end

  def set_color body: nil, color: nil
    vis_client.set_color body.uuid, color
  end

  def set_velocity body: nil, vector: nil
    sim_client.set_velocity body.uuid, vector.x, vector.y
  end

  def set_viewport zoom_level: 1, follow: nil
    follow_uuid = follow ? follow.uuid : nil
    vis_client.set_viewport zoom_level: zoom_level,
                            viewport_leader_uuid: follow_uuid
  end

  def collisions
    sim_client.collisions.map do |collision|
      collision['pair'].map do |uuid|
        get_body(uuid: uuid)
      end
    end
  end

  def run &blk
    loop do
      blk.call(self.tick_count)
      tick
      update_bodies
      draw_bodies
    end
  end
end

module CollidingBodies
  def handle_collisions
    collisions.each do |collidors|
      collidors.compact.permutation(2).each do |body1, body2|
        handle_collision bodies: [body1, body2]
      end
    end
  end

  def handle_collision body: nil
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


class Wall < Body
  def init_attrs
    self.color = 'gray'
    self.static = true
  end
end

class VerticalWall < Wall
  def init_attrs
    super
    self.width = 10
    self.height = 1600
  end
end

class HorizontalWall < Wall
  def init_attrs
    super
    self.width = 1600
    self.height = 10
  end
end
