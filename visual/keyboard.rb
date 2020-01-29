class Keyboard

  attr_accessor :keys_down

  def initialize input
    self.setup_listeners input
    self.keys_down = {}
  end

  def pressed? key
    self.keys_down[key] == true
  end

  def setup_listeners input
    input.keydown { |*args| keydown(*args) }
    input.keyup   { |*args| keyup(*args) }
  end

  def keydown key
    self.keys_down[key] = true
  end

  def keyup key
    self.keys_down[key] = false
  end
end

class KeyboardInterpreter
  attr_accessor :keyboard

  def initialize keyboard
    self.keyboard = keyboard
  end

  def directions
    moves = []
    mapping.each do |direction, keys|
      keys.each do |key|
        if keyboard.pressed? key
          moves << direction and break
        end
      end
    end
    moves
  end

  def keypresses
    moves = []
    mapping.each do |direction, keys|
      keys.each do |key|
        if keyboard.pressed? key
          moves << key
        end
      end
    end
    moves
  end

  def mapping
    { forward:         [:up, "w"],
      back:            [:down, "s"],
      left:            [:left, "a"],
      right:           [:right, "d"],
      rotate_right:    ["e"],
      rotate_left:     ["q"],
      jump:            [:space, " "]
    }
  end
end

