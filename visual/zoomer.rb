class Zoomer
  attr_accessor :zoom_level

  def initialize zoom_level: 1
    self.zoom_level = zoom_level
  end

  def zoom el_opts: nil, controller: nil
    zoomed_opts = el_opts.dup
    zoomed_opts[:top] = el_opts[:top] * zoom_multiplier() + ((controller.window_height / 4) * (self.zoom_level - 1))
    zoomed_opts[:left] = el_opts[:left] * zoom_multiplier() + ((controller.window_width / 4) * (self.zoom_level - 1))
    zoomed_opts[:width] = el_opts[:width] * zoom_multiplier()
    zoomed_opts[:height] = el_opts[:height] * zoom_multiplier()
    return zoomed_opts
  end

  def zoom_multiplier
    1.0 / zoom_level
  end

end