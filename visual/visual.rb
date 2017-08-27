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
    @bodies[uuid] = body
  end

  def remove body
    return false if body.nil?
    puts "bodiesBefore: #{@bodies.length}"
    @bodies.delete body.body_uuid
    puts "bodiesAfter: #{@bodies.length}"
    return true
  end

  def each &blk
    @bodies.values.each do |body|
      blk.call body
    end
  end

  def get body_uuid
    @bodies[body_uuid]
  end
end

class Controller
  attr_accessor :bodies, :clicks

  def add opts
    case opts['shape']
    when 'rectangle'
      l, t = self.class.to_lt opts['position']['x'], opts['position']['y']
      body_uuid = opts['body_uuid'] || SecureRandom.uuid.to_s
      body = OpenStruct.new(body_uuid: body_uuid,
                            shape: :rectangle, color: :black,
                            left: l, top: t,
                            width: opts['width'], height: opts['height'])
      bodies.add body
      return { body_uuid: body_uuid }
    end
  end

  def destroy opts
    body = bodies.get(opts['body_uuid'])
    puts "removing: #{body}"
    bodies.remove body
    return { body_uuid: opts['body_uuid'] }
  end

  def set_position opts
    body = bodies.get opts['body_uuid']
    l, t = self.class.to_lt opts['position']['x'], opts['position']['y']
    body.left = l
    body.top = t
    return { body_uuid: body.body_uuid }
  end

  def set_color opts
    body = bodies.get opts['body_uuid']
    body.color = opts['color']
    return { body_uuid: body.body_uuid }
  end

  def tick *_
    prev_clicks = self.clicks.dup
    self.clicks.clear
    return { clicks: prev_clicks }
  end

  private

  def self.to_lt x, y
    top = (WINDOW_WIDTH/2) - y
    left  = (WINDOW_HEIGHT/2) + x
    [left, top]
  end

  def self.to_xy l, t
    x = l - (WINDOW_HEIGHT/2)
    y = -(t - (WINDOW_HEIGHT/2))
    [x, y]
  end
end

clicks = []
bodies = BodyCollection.new
controller = Controller.new
controller.bodies = bodies
controller.clicks = clicks

File.unlink SOCKET_PATH rescue false
Thread.new do
  loop do
    begin
      puts "listening"
      UNIXServer.open(SOCKET_PATH) do |serv|
        s = serv.accept
        loop do
          data = JSON.load(s.gets)
          if data['messages']
            r = data['messages'].map do |message_data|
              controller.send message_data['message'], message_data
            end
            s.puts JSON.dump(r)
          else
            r = controller.send data['message'], data
            s.puts JSON.dump(r)
          end
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
      begin
        x, y = Controller.to_xy(left, top)
        clicks << { x: x, y: y }
      rescue => ex
        puts "CEX: #{ex}"
      end
    end

    animate(FPS) do
      begin
        clear
        image(WINDOW_WIDTH, WINDOW_HEIGHT) do
          bodies.each do |body|
            case body.shape
            when :rectangle
              fill self.send(body.color)
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
