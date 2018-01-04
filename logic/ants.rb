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

  def random_move_toward target: nil, game: nil
    # low odds atm
    random_target = [
      Location.new(x: 10,  y: 0)   + location,
      Location.new(x: -10, y: 0)   + location,
      Location.new(x: 0,   y: 10)  + location,
      Location.new(x: 0,   y: -10) + location,
      Location.new(x: 10,  y: 10)  + location,
      target.location
    ].sample
    move_toward target: random_target, game: game
  end

  def move_toward target: nil, game: nil
    return if target.nil?
    vector = location.scaled_vector_to target.location, scale: 10
    game.push body: self, vector: vector
    game.set_rotation body: self, rotation: location.angle_to(target.location)
  end

  def find_food foods
    foods.find { |food| on? food }
  end

  def eat_available_food game: nil, food: nil
    game.consume food: food
  end

  def tick game: nil
    if food = find_food(game.foods)
      eat_available_food game: game, food: food
    else
      move_toward target: game.foods.near(self), game: game
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
game.add_bodies bodies: game.walls[0..1], static: true, width: 800, height: 10
game.add_bodies bodies: game.walls[2..3], static: true, width: 10, height: 800
game.add_bodies bodies: game.foods, static: true, width: 3,   height: 3

# tick ants every 1 second
delta_count = 0
game.run do |step_delta|
  delta_count += step_delta
  game.update_bodies
  game.draw_bodies
  if delta_count >= 100
    puts "ticking"
    colony.tick game: game
    delta_count = delta_count % 100
  end
end
