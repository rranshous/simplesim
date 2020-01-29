require_relative 'client'
require_relative 'game'

class Shooter < Body
  def init_attrs
    self.location = Location.new(x: 0, y: 0)
    self.width = 20
    self.height = 20
  end
end

class Bullet < Body
  attr_accessor :speed, :density, :friction

  def init_attrs
    self.width = 5
    self.height = 5
    self.speed = 1
    self.density = 0.8
    self.friction = 0.001
  end
end

class Game

  KEY_DIRECTIONS = {
    'w' => 'forward',
    's' => 'backward',
    'a' => 'leftward',
    'd' => 'rightward'
  }

  attr_accessor :shooter, :bullets

  def init_attrs
    self.bullets = BodyCollection.new
    self.shooter = Shooter.new
    add_body body: shooter
  end

  def fire_bullet
    bullet = Bullet.new
    bullet.location = shooter.ahead distance: shooter.width + 2
    add_body body: bullet,
             density: bullet.density, frictionAir: bullet.friction
    velocity_vector = shooter.location.vector_to(shooter.ahead)
    velocity_vector *= Vector.new x: bullet.speed, y: bullet.speed
    set_velocity body: bullet,
                 vector: velocity_vector
  end

  def update_shooter_rotation
    set_rotation body: shooter,
                 rotation: shooter.angle_to(mouse_pos)
  end

  def handle_keypresses
    keypresses.each do |key|
      if KEY_DIRECTIONS.include? key
        push body: shooter, direction: KEY_DIRECTIONS[key]
      else
        if key == ' '
          fire_bullet
        end
      end
    end
  end

  def handle_clicks
    clicks.each do |loc|
      fire_bullet
    end
  end

  def handle_collisions
    collisions.each do |collidors|
    end
  end
end

game = Game.new
game.run do
  game.handle_keypresses
  game.handle_clicks
  game.handle_collisions
  game.update_shooter_rotation
  game.tick
end
