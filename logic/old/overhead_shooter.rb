require_relative 'client'
require_relative 'game'

class Body
  def survive_collision? body: nil
    true
  end
end

class Cursor < Body
  def init_attrs
    self.color = 'red'
    self.location = Location.new(x: 0, y: 0)
  end
end

class Wall < Body
  def init_attrs
    self.color = 'gray'
    self.static = true
  end
end

class VerticalWall < Wall
  def init_attrs
    super
    self.width = 10
    self.height = 1600
  end
end

class HorizontalWall < Wall
  def init_attrs
    super
    self.width = 1600
    self.height = 10
  end
end

class Baddy < Body
  include Mover

  def init_attrs
    self.color = 'blue'
    self.width = 10
    self.height = 7
    self.max_speed = 0.3
  end

  def survive_collision? body: nil
    return false if body.is_a?(Bullet)
    return false if body.is_a?(Shooter)
    return true
  end
end

class Shooter < Body
  include Mover

  def init_attrs
    self.location = Location.new(x: 0, y: 0)
    self.width = 20
    self.height = 20
    self.max_speed = 0.8
    self.acceleration = 0.05
    self.velocity = Vector.new(x: 0, y: 0)
  end

  def survive_collision? body: nil
    #return false if body.is_a?(Baddy)
    return true
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

  include CollidingBodies

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

  attr_accessor :shooter, :baddies, :max_baddies, :zoom_level,
                :viewport_follow, :last_fire_tick, :mouse_cursor

  def init_attrs
    self.shooter = Shooter.new
    self.mouse_cursor = Cursor.new
    self.baddies = BodyCollection.new
    self.max_baddies = 10
    self.zoom_level = 1
    self.last_fire_tick = 0
    self.viewport_follow = shooter
    add_body body: shooter
    #add_body body: mouse_cursor
    add_walls
  end

  def add_walls
    self.add_body body: HorizontalWall.new(location: Location.new(x: 0, y: 800))
    self.add_body body: HorizontalWall.new(location: Location.new(x: 0, y: -800))
    self.add_body body: VerticalWall.new(location: Location.new(x: -800, y: 0))
    self.add_body body: VerticalWall.new(location: Location.new(x: 800, y: 0))
  end

  def fire_bullet
    if self.last_fire_tick + 10 > self.tick_count
      return false
    end
    bullet = Bullet.new
    bullet.location = shooter.ahead distance: shooter.width + 2
    velocity_vector = shooter.location.vector_to(shooter.ahead)
    velocity_vector *= Vector.new x: bullet.speed, y: bullet.speed
    bullet.velocity = velocity_vector
    add_body body: bullet, frictionAir: bullet.friction
    self.last_fire_tick = self.tick
    return true
  end

  def update_shooter_rotation
    set_rotation body: shooter,
                 rotation: shooter.angle_to(mouse_pos)
  end

  def update_mouse_pointer
    mouse_cursor.location = mouse_pos
    mouse_cursor.rotation = mouse_cursor.angle_to(mouse_pos)
    update_position body: mouse_cursor
    update_rotation body: mouse_cursor
  end

  def fill_baddies
    (max_baddies - baddies.length).times do
      add_baddy
    end
  end

  def add_baddy
    baddy = Baddy.new
    loop do
      baddy.location = Location.new x: rand(-350..350),
                                    y: rand(-350..350)
      distance = shooter.location.distance_to(baddy.location)
      break if distance > 100
    end
    add_body body: baddy
    self.baddies << baddy
  end

  def update_baddies
    fill_baddies
    baddies.each do |baddy|
      baddy.velocity = baddy.vector_to(shooter.location)
      # is rotation working?
      set_rotation body: baddy,
                   rotation: baddy.angle_to(shooter.location)
      set_velocity body: baddy,
                   vector: baddy.velocity
    end
  end

  def handle_keypresses
    keypresses.each do |key|
      if KEY_DIRECTIONS.include? key
        handle_shooter_move KEY_DIRECTIONS[key]
      end
      if key == ' '
        fire_bullet
      end
      if key == 'i'
        self.zoom_level = 1
      end
      if key == 'o'
        self.zoom_level = 2
      end
      if key == 'k'
        self.viewport_follow = shooter
      end
      if key == 'l'
        self.viewport_follow = nil
      end
    end
  end

  def update_viewport
    set_viewport zoom_level: self.zoom_level,
                 follow: self.viewport_follow
  end

  def handle_shooter_move direction
    shooter.push game: self, direction: direction
  end

  def handle_clicks
    if clicks.length > 0
      fire_bullet
    end
  end

  def handle_collision bodies: nil
    body1, body2 = bodies
    if !body1.survive_collision? body: body2
      remove_body body: body1
      baddies.delete(body1) if body1.is_a?(Baddy)
    end
  end
end

game = Game.new
game.run do
  game.handle_keypresses
  game.handle_clicks
  game.handle_collisions
  game.update_shooter_rotation
  game.update_baddies
  #game.update_mouse_pointer
  game.update_viewport
end
