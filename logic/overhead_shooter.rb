require_relative 'client'
require_relative 'game'

class Shooter < Body
  def init_attrs
    self.location = Location.new(x: 0, y: 0)
  end
end

game = Game.new
shooter = Shooter.new
arrow = Body.new
arrow.location = Location.new(x: 100, y: 100)

game.add_body body: shooter
game.add_body body: arrow

KEY_DIRECTIONS = {
  'w' => 'forward',
  's' => 'backward',
  'a' => 'leftward',
  'd' => 'rightward'
}

game.run do

  arrow.location = shooter.left
  game.set_position body: arrow, position: arrow.location

  game.set_rotation body: shooter, rotation: shooter.angle_to(game.mouse_pos)

  game.keypresses.each do |key|
    game.push(body: shooter, direction: KEY_DIRECTIONS[key])
  end

  game.clicks.each do |loc|
  end

  game.vis_client.set_color arrow.uuid, 'red'
end
