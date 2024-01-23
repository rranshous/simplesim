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
      color = opts['color'] || 'yellow'
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

  def tick opts
    prev_clicks = self.clicks.dup
    self.clicks.clear
    prev_keypresses = self.keypresses.dup
    self.keypresses.clear
    x, y = Controller.to_xy(mouse_pos.x, mouse_pos.y)
    #x, y = self.zoomer.unzoom x: x, y: y, controller: self
    x, y = self.viewport_follower.unfollow x: x, y: y, controller: self
    return { mouse_pos: { x: x, y: y },
             clicks: prev_clicks,
             keypresses: prev_keypresses,
             tick_uuid: opts['tick_uuid'] }
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

class SocketReader
  def initialize socket
    @socket = socket
  end

  def each &blk
    loop do
      log_debug "reading from wire"
      wire_data = @socket.gets
      data = JSON.load(wire_data)
      log_debug "read #{data}"
      blk.call(data)
    end
  end
end

class SocketWriter
  def initialize socket
    @socket = socket
  end

  def write data
    @socket.puts JSON.dump(data)
  end
end

class SocketSerializer
  def initialize socket
    @socket_reader = SocketReader.new(socket)
    @socket_writer = SocketWriter.new(socket)
  end

  def each &blk
    @socket_reader.each &blk
  end

  def write data
    @socket_writer.write data
  end
end

class MessageReader
  def initialize socket_reader, high_priority_messages, low_priority_messages
    @high_priority_messages = high_priority_messages
    @low_priority_messages = low_priority_messages
    @socket_reader = socket_reader
  end

  def start
    @thread = Thread.new do
      begin
        handle_messages
      rescue => ex
        puts "TR EX: #{ex}"
        puts " : #{ex.backtrace}"
      end
    end    
  end

  def handle_messages
    @socket_reader.each do |message_data|
      if is_low_priority?(message_data)
        @low_priority_messages.push(message_data)
      else
        @high_priority_messages.push(message_data)
      end
    end
  end

  def is_low_priority? message_data
    ['set_position','set_rotation'].include?(message_data['message'])
  end
end

class MessageWriter
  def initialize socket_writer, outbound_queue
    @socket_writer = socket_writer
    @outbound_queue = outbound_queue
  end

  def start
    @thread = Thread.new do
      begin
        loop do
          log_debug "checking for replies"
          data = @outbound_queue.pop()
          log_debug "sending reply: #{data}"
          @socket_writer.write(data)
        end
      rescue => ex
        puts "TS EX: #{ex}"
        puts " : #{ex.backtrace}"
      end
    end
  end
end

class BackpressureQueue

  def initialize target_length
    @queue = Thread::Queue.new
    @target_length = target_length
  end

  def size
    @queue.size
  end

  def pop _
    amount_to_skip.times { @queue.pop(true) }
    @queue.pop(true)
  end

  def push data
    @queue.push(data)
  end

  def amount_to_skip
    @queue.size() / @target_length
  end
end

class QueueLooper
  def initialize queue
    @queue = queue
  end

  def each &blk
    loop do
      begin
        data = @queue.pop(true)
        blk.call(data)
      rescue ThreadError
        return
      end
    end
  end
end

class Renderer
  def initialize controller
    @controller = controller
    @updated_uuids = []
  end

  def register_update body_uuid
    @updated_uuids << body_uuid
  end

  def make_updates
    @updated_uuids
      .map { |uuid| @controller.bodies.get(uuid) }
      .compact
      .each { |body| update_body(body) }
    @updated_uuids.clear
  end

  def outstanding_updates_count
    @updated_uuids.size()
  end

  private

  def update_body body
    case body.shape
    when :rectangle
      degrees = Controller.to_deg body.rotation
      opts = {
        top: body.top, left: body.left,
        width: body.width, height: body.height,
        color: body.color
      }
      followed_opts = @controller.viewport_follow el_opts: opts
      if body.render_obj.nil?
        log_debug "creating new render obj"
        body.render_obj = Rectangle.new(
          x: followed_opts[:left], y: followed_opts[:top],
          width: followed_opts[:width], height: followed_opts[:height],
          color: followed_opts[:color]
        )
      else
        body.render_obj.x = followed_opts[:left]
        body.render_obj.y = followed_opts[:top]
        body.render_obj.width = followed_opts[:width]
        body.render_obj.height = followed_opts[:height]
        body.render_obj.color = followed_opts[:color]
      end
    end
  end
end


puts "removing socket"
File.unlink SOCKET_PATH rescue false

controller = Controller.new
controller.window_width = WINDOW_WIDTH
controller.window_height = WINDOW_HEIGHT

renderer = Renderer.new controller

high_priority_messages = Thread::Queue.new
low_priority_messages = BackpressureQueue.new(1000)
replies = Thread::Queue.new

puts "listening"
socket_serializer = SocketSerializer.new(UNIXServer.open(SOCKET_PATH).accept)

puts "starting message reader thread"
message_reader = MessageReader.new(socket_serializer, high_priority_messages, low_priority_messages)
message_reader.start

puts "starting socker responder thread"
message_writer = MessageWriter.new(socket_serializer, replies)
message_writer.start


set title: 'ruby2d visual', background: 'white',
    width: controller.window_width,
    height: controller.window_height

begin
  log "beginning"

  update_bodies = lambda do
    log "B: #{controller.bodies.size}\tQ: #{low_priority_messages.size()}\tS: #{low_priority_messages.amount_to_skip()}"

    log_debug "about to processes high priorty messages from thread"
    QueueLooper.new(high_priority_messages).each do |message|
      log_debug "processing high priority message: #{message}"
      replies.push(controller.send(message['message'], message))
      renderer.register_update(message['body_uuid'])
    end
    log_debug "done processing high priority queued messages"

    log_debug "about to processes low priorty messages from thread"
    QueueLooper.new(low_priority_messages).each do |message|
      body = controller.bodies.get(message['body_uuid'])
      log_debug "processing low message: #{message}"
      # it's possible a low priority message is out of order and the relevant
      # obj has been destroyed. only send message to controller if it's for
      # a body which still exists
      if body
        controller.send(message['message'], message)
        renderer.register_update(message['body_uuid'])
      end
    end
    log_debug "done processing low priority queued messages"
  
    log_debug "updating bodies: #{renderer.outstanding_updates_count()}"
    renderer.make_updates

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
