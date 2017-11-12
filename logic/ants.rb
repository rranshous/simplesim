require_relative 'client'
require 'ostruct'
FPS = 60
MAX_TICK_MS = 30

sim_client = Client.new(socket_path: '/tmp/sim.sock')
sim_client.connect

vis_client = Client.new(socket_path: '/tmp/vis.sock')
vis_client.extend(Batcher)
vis_client.connect

sim_client.set_gravity(0, 0)

class Ant
  extend Forwardable

  attr_accessor :food, :body_uuid, :location

  def_delegator :@location, :x, :y

  def random_walk_toward target: nil, scents: nil, sim: nil
    # low odds atm
    random_target = [
      Location.new(10, 0)  + location,
      Location.new(-10, 0) + location,
      Location.new(0, 10)  + location,
      Location.new(0, -10) + location,
      Location.new(10, 10) + location,
      target
    ].sample
    walk_toward target: random_target, scents: scents, sim: sim
  end

  def walk_toward target: nil, scents: nil, sim: nil
    vector = location.scaled_vector_to target
    sim.push uuid, vector.x, vector.y
  end

  def on_food? foods
    foods.include? location
  end

  def on_hill? hills
    hills.include? location
  end

  def eat_food
    self.food = true
  end

  def drop_food
    self.food = nil
  end

  def has_food?
    !self.food.nil?
  end
end

class LocationCollection
  attr_accessor :locations

  def initialize locations: []
    self.locations = locations
  end

  def << location
    self.locations << location
  end

  def near target_location
    raise ArgumentError if location.nil?
    locations.sort_by do |location|
      location.distance_to target_location
    end.first
  end
end

CENTER = Location.new(x: 0, y: 0)
ants   = []
foods  = LocationCollection.new(
  locations: [ Location.new(x: 100, y: 100),
               Location.new(x: -200, y: -50) ]
)
scents = LocationCollection.new
hills  = LocationCollection.new([CENTER])

10.times do
  ant = Ant.new
  ant.location  = CENTER
  ant.body_uuid = body_uuid
end

ants.each do |ant|

  if ant.has_food?
    ant.random_walk_toward target: hills.near(ant), scents: scents, sim: sim_client
  else
    ant.random_walk_toward target: scents.near(ant), scents: scents, sim: sim_client
  end

  if ant.on_food?(foods)
    ant.eat_food
  elsif ant.on_hill?(hills)
    ant.drop_food
  end

end
