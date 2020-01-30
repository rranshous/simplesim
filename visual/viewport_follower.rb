class ViewportFollower
  attr_accessor :leader

  def follow el_opts: nil, controller: nil
    if leader.nil?
      return el_opts
    end
    follow_opts = el_opts.dup
    #left = obj_left + distance_between_leader_left + center
    center = 400
    leader_left_offset = leader.left - (controller.window_width / 2)
    leader_top_offset = leader.top - (controller.window_height / 2)
    follow_opts[:top] = el_opts[:top] - leader_top_offset
    follow_opts[:left] = el_opts[:left] - leader_left_offset
    return follow_opts
  end
end
