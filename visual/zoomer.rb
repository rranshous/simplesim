require 'ostruct'

class Zoomer
  attr_accessor :zoom_level

  def initialize zoom_level: 1
    self.zoom_level = zoom_level
  end

  def zoom el_opts: nil, controller: nil
    zoomed_opts = el_opts.dup
    zoomed_opts[:top] = el_opts[:top].to_f * zoom_multiplier() + ((controller.window_height / 4) * (self.zoom_level - 1))
    zoomed_opts[:left] = el_opts[:left].to_f * zoom_multiplier() + ((controller.window_width / 4) * (self.zoom_level - 1))
    zoomed_opts[:width] = el_opts[:width].to_f * zoom_multiplier()
    zoomed_opts[:height] = el_opts[:height].to_f * zoom_multiplier()
    return zoomed_opts
  end

  def unzoom x: nil, y: nil, controller: nil
    zoom_level_divider = self.zoom_level - 1
    if zoom_level_divider == 0
      zoom_level_divider = 1
    end
    new_y = y.to_f % zoom_multiplier() - ((controller.window_height * 4) / zoom_level_divider)
    new_x = x.to_f % zoom_multiplier() - ((controller.window_width * 4) / zoom_level_divider)
    return [new_x, new_y]
  end

  def zoom_multiplier
    1.0 / zoom_level
  end

end
