require_relative 'client'

FPS = 60

sim_client = Client.new(socket_path: '/tmp/sim.sock')
sim_client.connect

vis_client = Client.new(socket_path: '/tmp/vis.sock')
vis_client.connect

sim_client.set_gravity(0, 0.1)

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
500.times do
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
  puts
  puts "loop:   #{diff_ms}"
  s = Time.now.to_f
  all_details = sim_client.list_details
  puts "detail: #{(Time.now.to_f - s) * 1000}"
  pos_updates = []
  s = Time.now.to_f
  all_details.each do |details|
    x, y = details['position']['x'], details['position']['y']
    pos_updates << [ details['body_uuid'], OpenStruct.new(x: x, y: y) ]
  end
  pos_updates.each do |update|
    vis_client.set_position(*update)
  end
  puts "set pos: #{(Time.now.to_f - s) * 1000}"
  s = Time.now.to_f
  sim_client.tick diff_ms
  puts "tick:   #{(Time.now.to_f - s) * 1000}"
end
