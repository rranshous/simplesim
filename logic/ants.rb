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
  attr_accessor :energy

  DIRECTIONS = [
    Location.new(x: 0,  y: 0),
    Location.new(x: 10,  y: 0),
    Location.new(x: -10, y: 0),
    Location.new(x: 0,   y: 10),
    Location.new(x: 0,   y: -10),
  ]

  def init_attrs
    self.energy = 100
  end

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
    game.consume food: food, eater: self
  end

  def consume food: nil
    self.energy += 1
  end

  def tick game: nil, nearby_food: []
    self.energy -= 1
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

class Game
  attr_accessor :scents, :hills, :ants, :foods, :walls

  def init_attrs
    self.scents = BodyCollection.new
    self.hills =  BodyCollection.new
    self.ants =   BodyCollection.new
    self.foods =  BodyCollection.new
    self.walls =  BodyCollection.new
  end

  def tick_ants
    ants.each do |ant|
      ant.tick game: self,
               nearby_food: foods.nearby(ant, max_distance: 20)
      if ant.energy <= 0
        kill ant: ant
        add_ant
      end
    end
  end

  def add_ant
    ant = Ant.new
    ant.location = CENTER + Location.new(x: rand(1..45), y: rand(1..45))
    self.ants << ant
    add_bodies bodies: [ant], density: 0.3
  end

  def add_food
    food = Body.new(location: Location.new(x: rand(-300..300),
                                           y: rand(-300..300)))
    self.foods << food
    add_bodies bodies: [food], static: true, width: 3, height: 3
  end

  def consume food: nil, eater: nil
    if food
      foods.delete food
      remove_body body: food
      add_food
    end
    if eater
      eater.consume food: food
    end
  end

  def kill ant: nil
    ants.delete ant
    remove_body body: ant
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
  game.add_food
end
5.times do
  game.add_ant
end

game.add_bodies bodies: game.hills, static: true, width: 25,  height: 25
game.add_bodies bodies: game.walls[0..1], static: true, width: 800, height: 100
game.add_bodies bodies: game.walls[2..3], static: true, width: 100, height: 800

delta_count = 0
game.run do |step_delta|
  delta_count += step_delta
  game.update_bodies
  game.draw_bodies
  if delta_count >= 100
    game.tick_ants
    delta_count = delta_count % 100
  end
end
