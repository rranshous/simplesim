require 'shoes'
require 'json'

require_relative '../logic/client.rb'

client = Client.new(socket_path: '/tmp/sim.sock')
client.connect

client.set_gravity 0, 0

data = client.add_square OpenStruct.new(x: 10, y:10), 10
body_uuid = data['body_uuid']

FPS = 10
WINDOW_WIDTH = 800
WINDOW_HEIGHT = 800

def to_lt x, y
  left = (WINDOW_WIDTH/2) + x
  top  = (WINDOW_HEIGHT/2) + y
  [left, top]
end


Shoes.app(width: WINDOW_WIDTH, height: WINDOW_HEIGHT, title: 'test') do
  begin
    last = Time.now.to_f
    animate(FPS) do
      begin
        puts "clearing"
        clear
        puts "ticking"
        diff_ms = (Time.now.to_f - last) * 1000
        client.tick diff_ms
        last = Time.now.to_f
        puts "getting details"
        details = client.detail({ body_uuid: body_uuid })
        puts "details: #{details}"
        x, y = details['position']['x'], details['position']['y']
        left, top = to_lt(x, y)
        width, height = [10, 10]
        puts "drawing"
        rect top, left, width, height
        puts "done drawing"
      rescue => ex
        puts "EX: #{ex}"
        raise
      end
    end
  rescue => ex
    puts "OEX: #{ex}"
    raise
  end
end
