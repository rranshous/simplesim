require_relative 'client'
require 'ostruct'

FPS = 60
MAX_TICK_MS = 30

def to_deg rad
  (rad * 180) / Math::PI
end

sim_client = Client.new(socket_path: '/tmp/sim.sock')
sim_client.connect

vis_client = BatcherClient.new(socket_path: '/tmp/vis.sock')
vis_client.connect

sim_client.set_gravity(0, 0)

destroyers = []
perminants = []
targets = []

shooter_loc = Location.new(x: 0, y: -300)

#r = sim_client.add_rectangle(
#  Location.new(x: 0, y: 300),
#  800, 10,
#  { static: true, density: 1, friction: 0.10 }
#)
#vis_client.add_rectangle(
#  Location.new(x: 0, y: 300),
#  800, 10,
#  { static: true, body_uuid: r['body_uuid'] }
#)
#perminants << r['body_uuid']

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
sim_client.set_anti_gravity shooter_body_uuid

vis_client.set_color(shooter_body_uuid, :red)
perminants << shooter_body_uuid

50.times do
  add_random_target.call
end

last = Time.now.to_f
loop do
  diff_ms = (Time.now.to_f - last) * 1000
  last = Time.now.to_f
  s = Time.now.to_f
  all_details = sim_client.list_details
  s = Time.now.to_f

  all_details.each do |details|
    x, y = details['position']['x'], details['position']['y']
    raise "skipping update: #{update}" if x.nil? || y.nil?
    loc = Location.new(x: x, y: y)
    vis_client.set_position(details['body_uuid'], loc)
    vis_client.set_rotation(details['body_uuid'], details['rotation'])
    if details['body_uuid'] == shooter_body_uuid
      shooter_loc = loc
    else
    end
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
  vis_updates = vis_client.tick_response
  mouse_pos = vis_updates['mouse_pos']
  mouse_offset = [ mouse_pos['x'] - shooter_loc.x,
                   mouse_pos['y'] - shooter_loc.y ]
  angle_to_mouse_rads = Math.atan2(mouse_offset[1], mouse_offset[0])
  mouse_offset_x = Math.cos(angle_to_mouse_rads)
  mouse_offset_y = Math.sin(angle_to_mouse_rads)
  sim_client.set_rotation(shooter_body_uuid, angle_to_mouse_rads)
  clicks = vis_updates['clicks']
  clicks.each do |pos|
    bullet_loc = shooter_loc + Location.new(x: mouse_offset_x * 20,
                                            y: mouse_offset_y * 20)
    r = sim_client.add_rectangle(
      bullet_loc, 3, 3,
      { density: 0.8, friction: 0.01 }
    )
    vis_client.add_rectangle(
      bullet_loc, 3, 3,
      { body_uuid: r['body_uuid'] }
    )
    x = pos['x'] - shooter_loc.x
    y = pos['y'] - shooter_loc.y
    puts "velocity: #{x/20.0}/#{y/20.0}"
    sim_client.set_velocity(r['body_uuid'], x / 20.0, y / 20.0)
    vis_client.set_color(r['body_uuid'], :red)
    destroyers.push(r['body_uuid'])
  end
  keypresses = vis_updates['keypresses']
  keypresses.uniq.each do |key|
    case key
    when "w"
      sim_client.push shooter_body_uuid, mouse_offset_x * 10, mouse_offset_y * 10
    when "a"
      sim_client.push shooter_body_uuid, -(mouse_offset_x * 10), 0
    when "s"
      sim_client.push shooter_body_uuid, -(mouse_offset_x * 10),
                                         -(mouse_offset_y * 10)
    when "d"
      sim_client.push shooter_body_uuid, mouse_offset_x * 10, 0
    end
  end
  #puts "tick:   #{(Time.now.to_f - s) * 1000}"
end


