require_relative 'client'
require 'ostruct'

FPS = 60
MAX_TICK_MS = 30

sim_client = Client.new(socket_path: '/tmp/sim.sock')
sim_client.connect

vis_client = Client.new(socket_path: '/tmp/vis.sock')
vis_client.extend(Batcher)
vis_client.connect

sim_client.set_gravity(0, 0.1)

destroyers = []
perminants = []
targets = []

shooter_loc = Location.new(x: 0, y: -300)

r = sim_client.add_rectangle(
  Location.new(x: 0, y: 300),
  800, 10,
  { static: true, density: 1, friction: 0.10 }
)
vis_client.add_rectangle(
  Location.new(x: 0, y: 300),
  800, 10,
  { static: true, body_uuid: r['body_uuid'] }
)
perminants << r['body_uuid']

add_random_target = lambda {
  r = sim_client.add_rectangle(
    Location.new(x: rand(-100..100), y: rand(-100..100)), 10, 10,
    { density: 0.1, friction: 0.01 }
  )
  vis_client.add_rectangle(
    Location.new(x: rand(-100..100), y: rand(-100..100)), 10, 10,
    { body_uuid: r['body_uuid'] }
  )
  targets << r['body_uuid']
}

r = sim_client.add_rectangle(
  shooter_loc,
  15, 15,
  { density: 0.8, friction: 0.01 }
)
shooter_body_uuid = r['body_uuid']
vis_client.add_rectangle(
  shooter_loc,
  15, 15,
  { body_uuid: shooter_body_uuid }
)
#sim_client.set_anti_gravity shooter_body_uuid

vis_client.set_color(shooter_body_uuid, :red)
perminants << shooter_body_uuid

100.times do
  add_random_target.call
end

last = Time.now.to_f
loop do
  diff_ms = (Time.now.to_f - last) * 1000
  last = Time.now.to_f
  s = Time.now.to_f
  all_details = sim_client.list_details
  pos_updates = []
  s = Time.now.to_f
  all_details.each do |details|
    x, y = details['position']['x'], details['position']['y']
    pos_updates << [ details['body_uuid'], Location.new(x: x, y: y) ]
  end
  pos_updates.each do |update|
    if update[1].x.nil? || update[1].y.nil?
      raise "skipping update: #{update}"
    end
    if update[0] == shooter_body_uuid
      shooter_loc = update[1]
    end
    vis_client.set_position(*update)
  end
  step_ms = [diff_ms, MAX_TICK_MS].min
  sim_updates = sim_client.tick step_ms
  sim_updates['collisions'].each do |collision|
    destroyer = (collision['pair'] & destroyers).first
    other = (collision['pair'] - [destroyer]).first
    perminant = perminants.include? other
    if !perminant && destroyer
      #vis_client.set_color(other, :red)
      sim_client.destroy other
      vis_client.destroy other
      sim_client.destroy destroyer
      vis_client.destroy destroyer
      targets.delete other
      targets.delete destroyer
      destroyers.delete other
      destroyers.delete destroyer
    end
  end
  vis_client.tick step_ms
  r = vis_client.send_batch
  vis_updates = r.last
  clicks = vis_updates['clicks']
  clicks.each do |pos|
    bullet_loc = shooter_loc + Location.new(y: 20)
    r = sim_client.add_rectangle(
      bullet_loc, 3, 3,
      { density: 0.8, friction: 0.01 }
    )
    vis_client.add_rectangle(
      bullet_loc, 3, 3,
      { body_uuid: r['body_uuid'] }
    )
    # this isn't write now that the origin can move
    sim_client.set_velocity(r['body_uuid'],
                            (shooter_loc.x + pos['x']) / 20.0,
                            (shooter_loc.y - pos['y']).abs / 20.0)
    vis_client.set_color(r['body_uuid'], :red)
    destroyers.push(r['body_uuid'])
  end
  keypresses = vis_updates['keypresses']
  keypresses.each do |key|
    case key
    when "w"
      sim_client.push shooter_body_uuid, 0, 10
    when "a"
      sim_client.push shooter_body_uuid, -10, 0
    when "s"
      sim_client.push shooter_body_uuid, 0, -10
    when "d"
      sim_client.push shooter_body_uuid, 10, 0
    end
  end
  #puts "tick:   #{(Time.now.to_f - s) * 1000}"
end


