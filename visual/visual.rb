require 'shoes'
require 'json'

require_relative '../logic/client.rb'

client = Client.new(socket_path: '/tmp/sim.sock')
client.connect

client.set_gravity(0, 0.1)

client.add_rectangle(
  OpenStruct.new(x: 0, y: 300),
  800, 10,
  { static: true }
)
100.times do
  client.add_square(OpenStruct.new(x: rand(-100..100), y: rand(-100..100)), 10)
end

FPS = 60
WINDOW_WIDTH = 800
WINDOW_HEIGHT = 800

def to_lt x, y
  top = (WINDOW_WIDTH/2) - y
  left  = (WINDOW_HEIGHT/2) + x
  [left, top]
end

def to_xy l, t
  x = l - (WINDOW_HEIGHT/2)
  y = -(t - (WINDOW_HEIGHT/2))
  [x, y]
end


Shoes.app(width: WINDOW_WIDTH, height: WINDOW_HEIGHT, title: 'test') do
  begin
    last = Time.now.to_f

    click do |_button, left, top|
      x, y = to_xy(left, top)
      client.add_square(OpenStruct.new(x: x, y: y), 10)
    end

    every(1) do
      puts "details"
      puts client.list_details
      puts
    end

    animate(FPS) do
      begin
        clear
        diff_ms = (Time.now.to_f - last) * 1000
        client.tick diff_ms
        last = Time.now.to_f
        image(WINDOW_WIDTH, WINDOW_HEIGHT) do
          client.list_details.each do |details|
            x, y = details['position']['x'], details['position']['y']
            width, height = details['width'], details['height']
            left, top = to_lt(x, y)
            rot = details['rotation'] * 180 / Math::PI
            puts "rot: #{rot}"
            rotate(rot)
            rect({
              top: top, left: left,
              width: width, height: height,
              center: true
            })
            rotate(-rot)
          end
        end
      rescue => ex
        puts "EX: #{ex}"
        puts " : #{ex.backtrace}"
        raise
      end
    end
  rescue => ex
    puts "OEX: #{ex}"
    puts " : #{ex.backtrace}"
    raise
  end
end
