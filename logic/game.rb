class Game

  FPS = 60
  MAX_TICK_MS = 30

  attr_accessor :vis_client, :sim_client, :last_tick_time

  def initialize
    init_clients
    init_game
  end

  def init_clients
    self.sim_client = Client.new(socket_path: '/tmp/sim.sock')
    self.vis_client = Client.new(socket_path: '/tmp/vis.sock')
    self.sim_client.connect
    self.vis_client.extend(Batcher)
    self.vis_client.connect
  end

  def init_game
    self.sim_client.set_gravity(0, 0)
  end

  def paint_screen
  end

  def update_locations locatables
  end

  def tick
    diff_ms = (Time.now.to_f - last_tick_time.to_f) * 1000
    step_ms = [diff_ms, MAX_TICK_MS].min
    sim_client.tick step_ms
    vis_client.tick step_ms
    self.last_tick_time = Time.now
  end

  def add_body body: nil
    r = sim_client.add_rectangle(
      body.location, 10, 10, { density: 0.1, friction: 0.01 }
    )
    vis_client.add_rectangle(
      body.location, 10, 10, { body_uuid: r['body_uuid'] }
    )
    body.uuid = r['body_uuid']
    return body
  end

  def update_bodies bodies: nil
    sim_client.list_details.each do |details|
      body_uuid = details['body_uuid']
      body = bodies.find { |b| b.uuid == body_uuid } # TODO: dont scan
      x, y = details['position']['x'], details['position']['y']
      loc = Location.new(x: x, y: y)
      body.location = loc
      body.rotation = details['rotation']
    end
  end

  def draw_bodies bodies
    bodies.each do |body|
      vis_client.set_position(body.uuid, body.location)
      vis_client.set_rotation(body.uuid, body.rotation)
    end
  end

  def push body: nil, vector: nil
    sim_client.push body.body_uuid, vector.x, vector.y
  end

  def loop &blk
    loop do
      blk.call
      tick
    end
  end

end
