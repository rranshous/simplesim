require_relative 'client'
require_relative 'game'
require 'ostruct'
require 'forwardable'

def log msg
  STDERR.write "#{msg}\n"
end

class Wall < Body
end

class Ant < Body
  attr_accessor :food

  def random_walk_toward target: nil, game: nil
    # low odds atm
    random_target = [
      Location.new(x: 10,  y: 0)   + location,
      Location.new(x: -10, y: 0)   + location,
      Location.new(x: 0,   y: 10)  + location,
      Location.new(x: 0,   y: -10) + location,
      Location.new(x: 10,  y: 10)  + location,
      target
    ].sample
    walk_toward target: random_target, game: game
  end

  def walk_toward target: nil, game: nil
    vector = location.scaled_vector_to target.location
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

  def tick game: nil
    if on_food?(game.foods)
      eat_food
    elsif on_hill?(game.hills)
      drop_food
    else
      target = has_food? ? game.hills.near(self) : game.foods.near(self)
      #random_walk_toward target: target, game: game
      walk_toward target: target, game: game
    end
  end
end

class AntColony
  attr_accessor :ants

  def tick game: nil
    game.ants.each do |ant|
      ant.tick game: game
    end
  end
end

class Game
  attr_accessor :scents, :hills, :ants, :foods, :walls

  def init_attrs
    self.scents = BodyCollection.new
    self.hills =  BodyCollection.new
    self.ants =   BodyCollection.new
    self.foods =  BodyCollection.new
    self.walls =  BodyCollection.new
  end
end

CENTER = Location.new(x: 0, y: 0)
game        = Game.new
game.walls << Wall.new(location: Location.new(x: 0, y: 300))
game.walls << Wall.new(location: Location.new(x: 0, y: -300))
game.walls << Wall.new(location: Location.new(x: -300, y: 0))
game.walls << Wall.new(location: Location.new(x: 300, y: 0))
game.foods << Body.new(location: Location.new(x: 100, y: 100))
game.foods << Body.new(location: Location.new(x: -200, y: -50))
game.hills << Body.new(location: CENTER.dup)
colony      = AntColony.new

1.times do
  ant = Ant.new
  ant.location = CENTER
  game.ants << ant
end

game.add_bodies bodies: game.ants, friction: 1, density: 0.5
game.add_bodies bodies: game.hills, static: true, width: 25,  height: 25
game.add_bodies bodies: game.walls[0..1], static: true, width: 800, height: 100
game.add_bodies bodies: game.walls[2..3], static: true, width: 100, height: 800
game.add_bodies bodies: game.foods, static: true, width: 3,   height: 3

game.run do
  game.update_bodies
  game.draw_bodies
  colony.tick game: game
end
