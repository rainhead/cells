class CellsTestOneCell < Cell::Base

  def super_state
    @my_class = self.class.to_s
    return
  end

  def instance_view
    render_state :renamed_instance_view
  end

  def state_with_no_view
  end

end
