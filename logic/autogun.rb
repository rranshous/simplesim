require_relative 'client'
require_relative 'game'

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

class AutoGun < Game
  include CollidingBodies
  include SimpleWalls

  attr_accessor :shooter, :mouse_cursor

  def init_attrs
    self.shooter = Shooter.new
    self.mouse_cursor = Cursor.new
    add_body body: self.shooter
    #add_body body: mouse_cursor
    #add_walls
    set_viewport follow: self.shooter
  end

  def handle_keypresses
    keypresses.each do |key|
      if KEY_DIRECTIONS.include? key
        shooter.push game: self, direction: KEY_DIRECTIONS[key]
      end
    end
  end

  def update_mouse_pointer
    mouse_cursor.location = mouse_pos
    mouse_cursor.rotation = mouse_cursor.angle_to(mouse_pos)
    update_position body: mouse_cursor
  end

  def update_shooter
    shooter.update_rotation game: self
  end
end

class Cursor < Body
  def init_attrs
    self.color = 'red'
    self.location = Location.new(x: 0, y: 0)
  end
end

class Shooter < Body
  include Mover

  attr_accessor :gun

  def init_attrs
    self.location = Location.new(x: 0, y: 0)
    self.width = 20
    self.height = 20
    self.max_speed = 0.8
    self.acceleration = 0.05
    self.velocity = Vector.new(x: 0, y: 0)
    #self.gun = Gun.new
  end

  def update_rotation game: nil
    turn_to game: game, rotation: self.angle_to(game.mouse_pos)
  end
end

class Gun < Body
  def init_attrs
    self.location = Location.new(x: 0, y: 0)
    self.width = 20
    self.height = 20
    self.color = 'blue'
  end

  def update_position shooter: nil
    self.location = shooter.ahead distance: 5
  end
end

game = AutoGun.new
game.run do
  game.handle_keypresses
  #game.update_mouse_pointer
  game.update_shooter
end
