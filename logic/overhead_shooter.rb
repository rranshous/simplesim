require_relative 'client'
require_relative 'game'

class Body
  def survive_collision? body: nil
    true
  end
end

class Wall < Body
  def init_attrs
    self.color = 'gray'
    self.static = true
  end
end

class Shooter < Body
  attr_accessor :max_speed, :acceleration

  def init_attrs
    self.location = Location.new(x: 0, y: 0)
    self.width = 20
    self.height = 20
    self.max_speed = 0.8
    self.acceleration = 0.05
    self.velocity = new_capped_vector
  end

  def velocity= other
    @velocity = new_capped_vector
    self.velocity.x = other.x
    self.velocity.y = other.y
    self.velocity
  end

  def new_capped_vector
    CappedVector.new max_x: self.max_speed,
                     max_y: self.max_speed
  end
end

class Bullet < Body
  attr_accessor :speed, :density, :friction

  def init_attrs
    self.width = 5
    self.height = 5
    self.speed = 3
    self.density = 0.8
    self.friction = 0.001
    self.color = 'red'
  end

  def survive_collision? body: nil
    return true if body.is_a?(Bullet)
    return true if self.static
    return false if body.static
  end
end

class Game

  KEY_DIRECTIONS = {
    #'w' => 'forward',
    #'s' => 'backward',
    #'a' => 'leftward',
    #'d' => 'rightward',
    'w' => 'absolute_up',
    's' => 'absolute_down',
    'a' => 'absolute_left',
    'd' => 'absolute_right',
  }

  attr_accessor :shooter, :walls

  def init_attrs
    self.shooter = Shooter.new
    self.walls = BodyCollection.new
    add_body body: shooter
    add_walls
  end

  def add_walls
    self.walls << Wall.new(location: Location.new(x: 0, y: 400))
    self.walls << Wall.new(location: Location.new(x: 0, y: -400))
    self.walls << Wall.new(location: Location.new(x: -400, y: 0))
    self.walls << Wall.new(location: Location.new(x: 400, y: 0))
    self.add_bodies bodies: self.walls[0..1], width: 800, height: 100
    self.add_bodies bodies: self.walls[2..3], width: 100, height: 800
  end

  def fire_bullet
    bullet = Bullet.new
    bullet.location = shooter.ahead distance: shooter.width + 2
    velocity_vector = shooter.location.vector_to(shooter.ahead)
    velocity_vector *= Vector.new x: bullet.speed, y: bullet.speed
    bullet.velocity = velocity_vector
    add_body body: bullet, frictionAir: bullet.friction
  end

  def update_shooter_details
    update_shooter_rotation
    update_shooter_velocity
  end

  def update_shooter_rotation
    set_rotation body: shooter,
                 rotation: shooter.angle_to(mouse_pos)
  end

  def update_shooter_velocity
    set_velocity body: shooter, vector: shooter.velocity
  end

  def handle_keypresses
    keypresses.each do |key|
      if KEY_DIRECTIONS.include? key
        handle_shooter_move KEY_DIRECTIONS[key]
      end
      if key == ' '
        fire_bullet
      end
    end
  end

  def handle_shooter_move direction
    shooter.velocity += shooter.send(direction) * shooter.acceleration
  end

  def handle_clicks
    if clicks.length > 0
      fire_bullet
    end
  end

  def handle_collisions
    collisions.each do |collidors|
      collidors.compact.permutation(2).each do |body1, body2|
        if !body1.survive_collision? body: body2
          remove_body body: body1
        end
      end
    end
  end
end

game = Game.new
game.run do
  game.handle_keypresses
  game.handle_clicks
  game.handle_collisions
  game.update_shooter_rotation
  game.update_shooter_velocity
end
