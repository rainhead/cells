# The Cells plugin defines a number of new methods for ActionView::Base.  These allow
# you to render cells from within normal controller views as well as from Cell state views.
module Cell

  module ActionView
    # Call a cell state and return its rendered view.
    #
    # ERB example:
    #   <div id="login">
    #     <%= render_cell :user, :login_prompt, :message => "Please login" %>
    #   </div>
    #
    # If you have a <tt>UserCell</tt> cell in <tt>app/cells/user_cell.rb</tt>, which has a
    # <tt>UserCell#login_prompt</tt> method, this will call that method and then will
    # find the view <tt>app/cells/user/login_prompt.html.erb</tt> and render it. This is 
    # called the <tt>:login_prompt</tt> <em>state</em> in Cells terminology.
    #
    # If this view file looks like this:
    #   <h1><%= @opts[:message] %></h1>
    #   <label>name: <input name="user[name]" /></label>
    #   <label>password: <input name="user[password]" /></label>
    #
    # The resulting view in the controller will be roughly equivalent to:
    #   <div id="login">
    #     <h1><%= "Please login" %></h1>
    #     <label>name: <input name="user[name]" /></label>
    #     <label>password: <input name="user[password]" /></label>
    #   </div>
    def render_cell(name, state, opts = {})
      opts[:template_format] ||= template_format
      cell = Cell::Base.create_cell_for(@controller, name, opts)
      cell.render_state(state)
    end
  end
  
  
  # These ControllerMethods are automatically added to all Controllers when
  # the cells plugin is loaded.
  module ActionController

    # Equivalent to ActionController#render_to_string, except it renders a cell
    # rather than a regular template.
    def render_cell_to_string(name, state, opts={})
      cell = Cell::Base.create_cell_for(self, name, opts)

      return cell.render_state(state)
    end
    
    # Render a cell and use it as the response.
    def render_cell(name, state, opts={})
      # ":layout => true": if there is a layout, use it.
      layout = opts.has_key?(:layout) ? opts.delete(:layout) : true
      render :text => render_cell_to_string(name, state, opts), :layout => layout
    end
  end
  
end



