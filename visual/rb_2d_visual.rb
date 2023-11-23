require 'ruby2d'
require 'json'
require 'thread'
require 'socket'
require 'securerandom'
require_relative 'keyboard'
require_relative 'zoomer'
require_relative 'viewport_follower'

def log msg
  STDERR.write "#{msg}\n"
  STDERR.flush
end

def log_time(label)
  start = Time.now.to_f
  r = yield
  t = (Time.now.to_f - start) * 1000
  if t < 0.01
    t = "~0"
  end
  log "#{label}: #{t}"
  r
end

FPS = 30
WINDOW_WIDTH = 400
WINDOW_HEIGHT = 400
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
  attr_accessor :bodies, :clicks, :keypresses, :mouse_pos,
                :pending_updates, :zoomer, :viewport_follower,
                :window_width, :window_height, :viewport_leader

  def initialize
    self.pending_updates = false
    self.bodies = BodyCollection.new
    self.clicks = []
    self.mouse_pos = OpenStruct.new(x: 0, y: 0)
    self.keypresses = []
    self.zoomer = Zoomer.new
    self.viewport_follower = ViewportFollower.new
  end

  def zoom el_opts: nil
    zoomer.zoom el_opts: el_opts, controller: self
  end

  def viewport_follow el_opts: nil
    viewport_follower.follow el_opts: el_opts, controller: self
  end

  def add opts
    case opts['shape']
    when 'rectangle'
      w, h = opts['width'], opts['height']
      l, t = self.class.to_lt opts['position']['x'], opts['position']['y'], w, h
      body_uuid = opts['body_uuid'] || SecureRandom.uuid.to_s
      color = opts['color'] || :black
      body = OpenStruct.new(body_uuid: body_uuid,
                            shape: :rectangle, color: color,
                            left: l, top: t, rotation: 0,
                            width: w, height: h)
      bodies.add body
      return { body_uuid: body_uuid }
    end
  end

  def destroy opts
    body = bodies.get(opts['body_uuid'])
    bodies.remove body
    return { body_uuid: opts['body_uuid'] }
  end

  def set_viewport opts
    self.zoomer.zoom_level = opts['zoom_level']
    if opts.include? 'viewport_leader_uuid'
      leader = bodies.get(opts['viewport_leader_uuid'])
      self.viewport_follower.leader = leader
    end
    to_return = { zoom_level: self.zoomer.zoom_level }
    if self.viewport_follower.leader
      to_return.merge!({
        viewport_leader_uuid: self.viewport_follower.leader.body_uuid
      })
    end
    return to_return
  end

  def set_position opts
    body = bodies.get opts['body_uuid']
    x, y = opts['position']['x'], opts['position']['y']
    w, h = body.width, body.height
    l, t = self.class.to_lt x, y, w, h
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
    x, y = Controller.to_xy(mouse_pos.x, mouse_pos.y)
    #x, y = self.zoomer.unzoom x: x, y: y, controller: self
    x, y = self.viewport_follower.unfollow x: x, y: y, controller: self
    return { mouse_pos: { x: x, y: y },
             clicks: prev_clicks,
             keypresses: prev_keypresses }
  end

  private

  def self.to_lt x, y, w, h
    top = (WINDOW_WIDTH/2) - y - h/2
    left  = (WINDOW_HEIGHT/2) + x - w/2
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
controller.window_width = WINDOW_WIDTH
controller.window_height = WINDOW_HEIGHT

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
          controller.pending_updates = true
        end
      end
    rescue => ex
      puts "TEX: #{ex}"
      puts " : #{ex.backtrace}"
    end
  end
end

set title: 'ruby2d visual', background: 'white',
    width: controller.window_width,
    height: controller.window_height

begin
  log "beginning"
  update_bodies = lambda do
    controller.pending_updates = false
    controller.bodies.each do |body|
      case body.shape
      when :rectangle
        degrees = Controller.to_deg body.rotation
        opts = {
          top: body.top, left: body.left,
          width: body.width, height: body.height,
          color: body.color
        }
        followed_opts = controller.viewport_follow el_opts: opts
        Rectangle.new(
          x: followed_opts[:left], y: followed_opts[:top],
          width: followed_opts[:width], height: followed_opts[:height],
          color: followed_opts[:color]
        )
      end
    end
  end

  update do
    print '.'
    begin
      if controller.pending_updates
        clear
        update_bodies.call()
      end
    rescue => ex
      puts "EX: #{ex}"
      puts " : #{ex.backtrace}"
      raise
    end
  end

  show

rescue => ex
  puts "OEX: #{ex}"
  puts " : #{ex.backtrace}"
  raise
end

log "at end"
