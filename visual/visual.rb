require 'shoes'
require 'json'
require 'thread'
require 'socket'
require 'securerandom'

FPS = 60
WINDOW_WIDTH = 800
WINDOW_HEIGHT = 800
SOCKET_PATH = "/tmp/vis.sock"

class BodyCollection
  def initialize
    @bodies = {}
    @lock = Mutex.new
  end

  def add body
    uuid = body['body_uuid']
    @lock.synchronize { @bodies[uuid] = body }
  end

  def each &blk
    bodies = @lock.synchronize { @bodies.dup }
    bodies.values.each do |body|
      @lock.synchronize { blk.call body }
    end
  end

  def get body_uuid
    @lock.synchronize { @bodies[body_uuid] }
  end
end

class Controller
  attr_accessor :bodies

  def add opts
    case opts['shape']
    when 'rectangle'
      l, t = to_lt opts['position']['x'], opts['position']['y']
      body_uuid = opts['body_uuid'] || SecureRandom.uuid.to_s
      body = OpenStruct.new(body_uuid: body_uuid, shape: :rectangle,
                            left: l, top: t,
                            width: opts['width'], height: opts['height'])
      bodies.add body
      return { body_uuid: body_uuid }
    end
  end

  def set_position opts
    body = bodies.get opts['body_uuid']
    l, t = to_lt opts['position']['x'], opts['position']['y']
    body.left = l
    body.top = t
    return { body_uuid: body.body_uuid }
  end

  private

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
end

bodies = BodyCollection.new
controller = Controller.new
controller.bodies = bodies

File.unlink SOCKET_PATH rescue false
Thread.new do
  loop do
    begin
      puts "listening"
      UNIXServer.open(SOCKET_PATH) do |serv|
        s = serv.accept
        loop do
          data = JSON.load(s.gets)
          r = controller.send data['message'], data
          s.puts JSON.dump(r)
        end
      end
    rescue => ex
      puts "TEX: #{ex}"
      puts " : #{ex.traceback}"
    end
  end
end

Shoes.app(width: WINDOW_WIDTH, height: WINDOW_HEIGHT, title: 'test') do
  begin

    click do |_button, left, top|
      x, y = to_xy(left, top)
      client.add_square(OpenStruct.new(x: x, y: y), 10)
    end

    animate(FPS) do
      begin
        clear
        image(WINDOW_WIDTH, WINDOW_HEIGHT) do
          bodies.each do |body|
            case body.shape
            when :rectangle
              rect({
                top: body.top, left: body.left,
                width: body.width, height: body.height,
                center: true
              })
            end
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
