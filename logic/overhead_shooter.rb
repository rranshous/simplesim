require_relative 'client'
require_relative 'game'

class Shooter < Body
  def init_attrs
    self.location = Location.new(x: 0, y: 0)
  end
end

game = Game.new
shooter = Shooter.new

game.add_body body: shooter

KEY_DIRECTIONS = {
  'w' => 'forward',
  's' => 'backward',
  'a' => 'leftward',
  'd' => 'rightward'
}

game.run do

  game.set_rotation body: shooter, rotation: shooter.angle_to(game.mouse_pos)

  game.keypresses.each do |key|
    game.push(body: shooter, direction: KEY_DIRECTIONS[key])
  end

  game.clicks.each do |loc|
  end
end
