require 'forwardable'

class Board
  extend Forwardable

  attr_accessor :game, :bodies

  def_delegators :@game, :push, :set_rotation,
                         :set_position, :set_velocity

  def add_body body: nil, type: :misc
    game.register_body body: body
    bodies.add_body body: body, type: type
  end
end
