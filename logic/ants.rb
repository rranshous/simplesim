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

  DIRECTIONS = [
    Location.new(x: 0,  y: 0),
    Location.new(x: 10,  y: 0),
    Location.new(x: -10, y: 0),
    Location.new(x: 0,   y: 10),
    Location.new(x: 0,   y: -10),
  ]

  def random_move_toward target: nil, game: nil
    # low odds atm
    random_target = DIRECTIONS.sample + location
    move_toward target: random_target, game: game
  end

  def move_randomly game: nil
    random_target = DIRECTIONS.sample + location
    unless :NO_MOVE == random_target
      move_toward target: random_target, game: game
    end
  end

  def move_toward target: nil, game: nil
    return if target.nil?
    loc = target.respond_to?(:location) ? target.location : target
    vector = location.scaled_vector_to loc, scale: 10
    game.push body: self, vector: vector
    game.set_rotation body: self, rotation: location.angle_to(loc)
  end

  def find_food foods
    foods.find { |food| on? food }
  end

  def eat_available_food game: nil, food: nil
    game.consume food: food
  end

  def tick game: nil, nearby_food: []
    if nearby_food.size == 0
      move_randomly game: game
    else
      if food = find_food(nearby_food)
        eat_available_food game: game, food: food
      else
        move_toward target: nearby_food.first, game: game
      end
    end
  end
end

class AntColony
  attr_accessor :ants

  def tick game: nil
    game.ants.each do |ant|
      ant.tick game: game,
               nearby_food: game.foods.nearby(ant)
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
game.walls << Wall.new(location: Location.new(x: 0, y: 400))
game.walls << Wall.new(location: Location.new(x: 0, y: -400))
game.walls << Wall.new(location: Location.new(x: -400, y: 0))
game.walls << Wall.new(location: Location.new(x: 400, y: 0))
game.hills << Body.new(location: CENTER.dup)
100.times do
  game.foods << Body.new(location: Location.new(x: rand(-300..300),
                                                y: rand(-300..300)))
end
5.times do
  ant = Ant.new
  ant.location = CENTER + Location.new(x: rand(1..45), y: rand(1..45))
  game.ants << ant
end
colony      = AntColony.new

game.add_bodies bodies: game.ants, density: 0.3
game.add_bodies bodies: game.hills, static: true, width: 25,  height: 25
game.add_bodies bodies: game.walls[0..1], static: true, width: 800, height: 100
game.add_bodies bodies: game.walls[2..3], static: true, width: 100, height: 800
game.add_bodies bodies: game.foods, static: true, width: 3,   height: 3

delta_count = 0
game.run do |step_delta|
  delta_count += step_delta
  game.update_bodies
  game.draw_bodies
  if delta_count >= 100
    colony.tick game: game
    delta_count = delta_count % 100
  end
end
