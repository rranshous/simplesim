require 'ruby2d'
require 'json'
require 'thread'
require 'socket'
require 'securerandom'
require_relative 'keyboard'
require_relative 'zoomer'
require_relative 'viewport_follower'

DEBUG = false

def log msg
  STDERR.write "#{msg}\n"
  STDERR.flush
end

def log_debug msg
  if DEBUG
    log msg
  end
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
WINDOW_WIDTH = 1000
WINDOW_HEIGHT = 1000
SOCKET_PATH = "/tmp/vis.sock"

# TODO: can/should we be using the BodyCollection obj
# from logic/lib?
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

  def size
    @bodies.size
  end
end

class Controller
  attr_accessor :bodies, :clicks, :keypresses, :mouse_pos,
                :pending_updates, :zoomer, :viewport_follower,
                :window_width, :window_height, :viewport_leader,
                :destroyed_render_objs

  def initialize
    self.pending_updates = false
    self.bodies = BodyCollection.new
    self.clicks = []
    self.mouse_pos = OpenStruct.new(x: 0, y: 0)
    self.keypresses = []
    self.zoomer = Zoomer.new
    self.viewport_follower = ViewportFollower.new
    self.destroyed_render_objs = []
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
      color = opts['color'] || 'purple'
      body = OpenStruct.new(body_uuid: body_uuid,
                            shape: :rectangle, color: color,
                            left: l, top: t, rotation: 0,
                            width: w, height: h,
                            render_obj: nil)
      bodies.add body
      return { body_uuid: body_uuid }
    end
  end

  def destroy opts
    body = bodies.get(opts['body_uuid'])
    bodies.remove body
    self.destroyed_render_objs << body.render_obj
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

high_priority_messages = Thread::Queue.new
low_priority_messages = Thread::Queue.new
replies = Thread::Queue.new

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
          log_debug "thread got data: #{data}"
          (data['messages'] || [data]).each do |message_data|
            log_debug "thread enqueuing message data: #{message_data}"
            if ['set_position','set_rotation'].include?(message_data['message'])
              low_priority_messages << message_data
            else
              high_priority_messages << message_data
            end
          end
          log_debug "thread waiting for reploy"
          reply = replies.pop
          log_debug "thread got reply: #{reply}"
          s.puts JSON.dump(reply)
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

  update_body = lambda do |controller, body|
    case body.shape
    when :rectangle
      degrees = Controller.to_deg body.rotation
      opts = {
        top: body.top, left: body.left,
        width: body.width, height: body.height,
        color: body.color
      }
      followed_opts = controller.viewport_follow el_opts: opts
      if body.render_obj.nil?
        log_debug "creating new render obj"
        body.render_obj = Rectangle.new(
          x: followed_opts[:left], y: followed_opts[:top],
          width: followed_opts[:width], height: followed_opts[:height],
          color: followed_opts[:color]
        )
      else
        body.render_obj.x = followed_opts[:left] if body.render_obj.x != followed_opts[:left]
        body.render_obj.y = followed_opts[:top] if body.render_obj.y != followed_opts[:top]
        body.render_obj.width = followed_opts[:width] if body.render_obj.width != followed_opts[:width]
        body.render_obj.height = followed_opts[:height] if body.render_obj.height != followed_opts[:height]
        body.render_obj.color = followed_opts[:color] if body.render_obj.color != followed_opts[:color]
      end
    end
  end

  update_bodies = lambda do
    skip_amt = low_priority_messages.size() / 1000
    log "B: #{controller.bodies.size}\tQ: #{low_priority_messages.size()}\tS: #{skip_amt}"
    reply = []
    updated_uuids = []
    log_debug "about to processes high priorty messages from thread"
    begin
      while message = high_priority_messages.pop(true)
        log_debug "processing high priority message: #{message}"
        reply << controller.send(message['message'], message)
        updated_uuids << message['body_uuid']
      end
    rescue ThreadError
      log_debug "done processing high priority queued messages"
    end

    log_debug "about to processes low priorty messages from thread"
    begin
      100.times do
        message = low_priority_messages.pop(true)
        body = controller.bodies.get(message['body_uuid'])
        log_debug "processing low message: #{message}"
        # it's possible a low priority message is out of order and the relevant
        # obj has been destroyed. only send message to controller if it's for
        # a body which still exists
        if body
          controller.send(message['message'], message)
          updated_uuids << message['body_uuid']
        end
        skip_amt.times { low_priority_messages.pop(true) }
      end
    # queue is empty
    rescue ThreadError
      log_debug "done processing low priority queued messages"
    else
      # queue_size = low_priority_messages.size()
      # if queue_size > 1000
      #   log "queue length too high (#{low_priority_messages.size()}) - removing some queued items"
      #   (queue_size/2).times { low_priority_messages.pop(true) } rescue ThreadError
      # else
      #   log_debug "queue length: #{low_priority_messages.size()}"
      # end
    end

    log_debug "updating bodies: #{updated_uuids.size}"
    updated_uuids.each do |uuid|
      body = controller.bodies.get(uuid)
      if body
        update_body.call(controller, body)
      end
    end

    controller.destroyed_render_objs.delete_if do |render_obj|
      begin
        render_obj.remove
      rescue
        # removed before it's been rendered?
        true
      ensure
        true
      end
    end
    if !reply.empty?
      replies << reply
    end
  end

  update do
    begin
      update_bodies.call()
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
