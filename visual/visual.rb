require 'shoes'
require 'json'
require 'thread'
require 'socket'
require 'securerandom'
require_relative 'keyboard'

FPS = 30
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
    @bodies.delete body.body_uuid
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
  attr_accessor :bodies, :clicks, :keypresses, :mouse_pos

  def add opts
    case opts['shape']
    when 'rectangle'
      l, t = self.class.to_lt opts['position']['x'], opts['position']['y']
      body_uuid = opts['body_uuid'] || SecureRandom.uuid.to_s
      color = opts['color'] || :black
      body = OpenStruct.new(body_uuid: body_uuid,
                            shape: :rectangle, color: color,
                            left: l, top: t, rotation: 0,
                            width: opts['width'], height: opts['height'])
      bodies.add body
      return { body_uuid: body_uuid }
    end
  end

  def destroy opts
    body = bodies.get(opts['body_uuid'])
    bodies.remove body
    return { body_uuid: opts['body_uuid'] }
  end

  def set_position opts
    body = bodies.get opts['body_uuid']
    x, y = opts['position']['x'], opts['position']['y']
    l, t = self.class.to_lt x, y
    body.left = l
    body.top = t
    return { body_uuid: body.body_uuid }
  end

  def set_rotation opts
    body = bodies.get opts['body_uuid']
    body.rotation = opts['rotation']
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
    prev_keypresses = self.keypresses.dup
    self.keypresses.clear
    return { mouse_pos: { x: mouse_pos.x, y: mouse_pos.y },
             clicks: prev_clicks,
             keypresses: prev_keypresses }
  end

  private

  def self.to_lt x, y
    top = (WINDOW_WIDTH/2) - y
    left  = (WINDOW_HEIGHT/2) + x
    [left, top]
  end

  def self.to_xy l, t
    x = l - (WINDOW_WIDTH/2)
    y = -(t - (WINDOW_HEIGHT/2))
    [x, y]
  end

  def self.to_deg rad
    (rad * 180) / Math::PI
  end
end

controller = Controller.new
controller.bodies = BodyCollection.new
controller.clicks = []
controller.mouse_pos = OpenStruct.new(x: 0, y: 0)
controller.keypresses = []

Thread.new do
  loop do
    begin
      puts "removing socket"
      File.unlink SOCKET_PATH rescue false
      puts "listening"
      UNIXServer.open(SOCKET_PATH) do |serv|
        s = serv.accept
        loop do
          wire_data = s.gets
          data = JSON.load(wire_data)
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
      puts " : #{ex.backtrace}"
    end
  end
end

Shoes.app(width: WINDOW_WIDTH, height: WINDOW_HEIGHT, title: 'test') do
  begin

    keyboard = Keyboard.new self
    keyboard_interpreter = KeyboardInterpreter.new keyboard

    click do |_button, left, top|
      begin
        x, y = Controller.to_xy(left, top)
        controller.clicks << { x: x, y: y }
      rescue => ex
        puts "CEX: #{ex}"
      end
    end

    motion do |left, top|
      controller.mouse_pos.x, controller.mouse_pos.y = Controller.to_xy(left, top)
    end

    load_keypresses = lambda do
      keyboard_interpreter.keypresses.each do |key|
        controller.keypresses << key
      end
    end

    update_bodies = lambda do
      controller.bodies.each do |body|
        case body.shape
        when :rectangle
          color = self.send(body.color) rescue body.color
          degrees = Controller.to_deg body.rotation
          rotate degrees
          fill color
          rect({
            top: body.top, left: body.left,
            width: body.width, height: body.height,
            center: true
          })
          rotate(-degrees)
        end
      end
    end

    animate(FPS) do |i|
      puts "visual bodies: #{controller.bodies.size}" if i % 100 == 0
      begin
        clear
        load_keypresses.call()
        update_bodies.call()
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
