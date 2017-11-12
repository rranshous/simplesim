require_relative 'client'
require 'ostruct'


class Ant
  extend Forwardable

  attr_accessor :food, :uuid, :location, :rotation

  def_delegator :@location, :x, :y

  def random_walk_toward target: nil, game: nil
    # low odds atm
    random_target = [
      Location.new(10, 0)  + location,
      Location.new(-10, 0) + location,
      Location.new(0, 10)  + location,
      Location.new(0, -10) + location,
      Location.new(10, 10) + location,
      target
    ].sample
    walk_toward target: random_target, game: game
  end

  def walk_toward target: nil, game: nil
    vector = location.scaled_vector_to target
    #game.scents << location.dup #?
    game.push body: self, vector: vector
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

class AntColony
  attr_accessor :ants

  def tick game: nil
    game.ants.each do |ant|
      if ant.on_food?(foods)
        ant.eat_food
      elsif ant.on_hill?(hills)
        ant.drop_food
      else
        target = ant.has_food? ? hills.near(ant) : scents.near(ant)
        ant.random_walk_toward target: target, game: game
      end
    end
  end
end

class Game
  attr_accessor :scents, :hills, :ants
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

  def each &blk
    locations.each(&blk)
  end
end

CENTER = Location.new(x: 0, y: 0)
game        = Game.new
game.foods  = LocationCollection.new(
  locations: [ Location.new(x: 100, y: 100),
               Location.new(x: -200, y: -50) ]
)
game.scents = LocationCollection.new
game.hills  = LocationCollection.new([CENTER])
game.ants   = []
colony      = AntColony.new

10.times do
  ant = Ant.new
  ant.location  = CENTER
  game.ants << ant
end

game.ants.each do |ant|
  game.add_body ant
end

game.hills.each do |hill|
  game.add_body hill
end

game.loop do
  game.update_bodies ants + hills
  game.draw_bodies   ants + hills
  colony.tick        game
end
