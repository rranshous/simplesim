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

  attr_accessor :shooter, :gun, :baddies

  def init_attrs
    self.shooter = Shooter.new
    add_body body: self.shooter
    self.gun = Gun.new
    add_body body: self.gun
    self.gun.shooter = self.shooter
    self.baddies = BodyCollection.new
    add_walls
    add_baddies
    set_viewport follow: self.shooter
  end

  def add_baddies
    10.times do
      baddy = Baddy.new
      add_body body: baddy
      self.baddies << baddy
    end
  end

  def baddies_near target: nil
    self.baddies.nearby target.location, max_distance: 100
  end

  def handle_keypresses
    keypresses.each do |key|
      if KEY_DIRECTIONS.include? key
        shooter.push game: self, direction: KEY_DIRECTIONS[key]
      end
    end
  end

  def update_shooter
    shooter.update_rotation game: self
  end

  def update_gun
    gun.update game: self
  end

  def update_baddies
    baddies.each do |baddy|
      baddy.update game: self
    end
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
    self.color = 'black'
    self.width = 20
    self.height = 20
    self.max_speed = 0.8
    self.acceleration = 0.05
    self.velocity = Vector.new(x: 0, y: 0)
    self.location = Location.new(x: 0, y: 0)
  end

  def update_rotation game: nil
    turn_to game: game, rotation: self.angle_to(game.mouse_pos)
  end
end

class Baddy < Body
  include Mover

  def init_attrs
    self.color = 'green'
    self.width = 15
    self.height = 15
    self.max_speed = 0.4
    self.acceleration = 0.03
    self.velocity = Vector.new(x: 0, y: 0)
    self.location = Location.new(x: rand(-200..200), y: rand(-200..200))
  end

  def update game: nil
    update_velocity game: game
    update_rotation game: game
  end

  def update_velocity game: nil
    go_toward game: game, target: game.shooter
  end

  def update_rotation game: nil
    turn_toward game: game, target: game.shooter
  end
end

class Gun < Body
  include Mover

  attr_accessor :shooter

  def init_attrs
    self.location = Location.new(x: 0, y: 0)
    self.width = 7
    self.height = 3
    self.color = 'blue'
  end

  def update game: nil
    update_position game: game
    update_rotation game: game
  end

  def update_position game: nil
    distance = shooter.width + 3
    go_to game: game,
          position: shooter.ahead(distance: distance)
  end

  def update_rotation game: nil
    nearby_enemies = game.baddies_near(target: self)
    if !nearby_enemies.empty?
      turn_toward game: game,
                  target: nearby_enemies.first
    else
      turn_to game: game,
              rotation: angle_to(game.shooter.ahead(distance: 100))
    end
  end
end

game = AutoGun.new
game.run do
  game.handle_keypresses
  game.update_shooter
  game.update_gun
  game.update_baddies
end
