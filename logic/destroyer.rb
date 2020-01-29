require_relative 'client'

FPS = 60
MAX_TICK_MS = 30

sim_client = Client.new(socket_path: '/tmp/sim.sock')
sim_client.connect

vis_client = BatcherClient.new(socket_path: '/tmp/vis.sock')
vis_client.connect

sim_client.set_gravity(0, 0.1)

destroyers = []
perminants = []

r = sim_client.add_rectangle(
  OpenStruct.new(x: 0, y: 300),
  800, 10,
  { static: true }
)
vis_client.add_rectangle(
  OpenStruct.new(x: 0, y: 300),
  800, 10,
  { static: true, body_uuid: r['body_uuid'] }
)
perminants << r['body_uuid']

100.times do
  r = sim_client.add_rectangle(
    OpenStruct.new(x: rand(-100..100), y: rand(-100..100)), 10, 10
  )
  vis_client.add_rectangle(
    OpenStruct.new(x: rand(-100..100), y: rand(-100..100)), 10, 10,
    { body_uuid: r['body_uuid'] }
  )
end

last = Time.now.to_f
loop do
  diff_ms = (Time.now.to_f - last) * 1000
  last = Time.now.to_f
  #puts
  #puts "loop:   #{diff_ms}"
  s = Time.now.to_f
  all_details = sim_client.list_details
  pos_updates = []
  s = Time.now.to_f
  all_details.each do |details|
    x, y = details['position']['x'], details['position']['y']
    pos_updates << [ details['body_uuid'], OpenStruct.new(x: x, y: y) ]
  end
  pos_updates.each do |update|
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
    end
  end
  vis_client.tick step_ms
  vis_updates = vis_client.tick_response
  clicks = vis_updates['clicks']
  clicks.each do |pos|
    r = sim_client.add_rectangle(
      OpenStruct.new(x: pos['x'], y: pos['y']),
      10, 10
    )
    vis_client.add_rectangle(
      OpenStruct.new(x: pos['x'], y: pos['y']),
      10, 10,
      { body_uuid: r['body_uuid'] }
    )
    vis_client.set_color(r['body_uuid'], :red)
    destroyers.push(r['body_uuid'])
  end
  #puts "tick:   #{(Time.now.to_f - s) * 1000}"
end

