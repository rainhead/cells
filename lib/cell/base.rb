# This implementation of Cells is mostly for internal use, so there will be little documentation, and
# the tests are guaranteed to be out of date.

module Cell
  class Base
    include ActionController::Helpers
    include ActionController::RequestForgeryProtection
    include Cell::ActionView
    
    helper ApplicationHelper
    
    class << self
      # Declare your class abstract to prevent it from generating a default view
      # template (from subclass.view_template). Handy for abstract base classes
      # that will not have their own template files:
      #   class AbstractCell < Cell::Base
      #     self.abstract_class = true
      #   end
      attr_accessor :abstract_class

      # Forgery protection for forms
      attr_accessor :request_forgery_protection_token

      def inherited(subclass)
        super
        return if subclass.abstract_class?
        subclass.add_view_template subclass.view_template
      end
      
      # Creates a cell instance of the class <tt>name</tt>Cell, passing through 
      # <tt>opts</tt>.
      def create_cell_for(controller, name, opts={})
        class_from_cell_name(name).new(controller, opts)
      end
      
      # A template file will be looked for in each view path. This is typically
      # just RAILS_ROOT/app/cells, but you might want to add e.g.
      # RAILS_ROOT/app/views.
      def add_view_path(path)
        self.view_paths << RAILS_ROOT + '/' + path
      end
    
      # Propose a template name for cells of this type. These accumulate down the
      # inheritence chain. The format is of an uninterpolated string:
      #   class FooCell < Cell::Base
      #     attr_accessor :knob1, :knob2
      #     add_view_template cell_name + '/#{knob1}-{#knob2}/#{state}'
      #   end
      def add_view_template(tmpl)
        self.view_templates.unshift tmpl
      end
      
      def abstract_class?
        abstract_class == true
      end
      
      # This is the template name each Cell::Base concrete subclass will propose
      # when searching for a template file to render the state.
      def view_template
        cell_name + '/#{state}'
      end
      
      # Get the name of this cell's class as an underscored string,
      # with _cell removed.
      #
      # Example:
      #  UserCell.cell_name
      #  => "user"
      def cell_name
        self.name.underscore.sub(/_cell\Z/, '')
      end

      # Given a cell name, find the class that belongs to it.
      #
      # Example:
      # Cell::Base.class_from_cell_name(:user)
      # => UserCell
      def class_from_cell_name(cell_name)
        "#{cell_name}_cell".classify.constantize
      end

      # Delegate the named method(s) to the controller
      def controller_method(*methods)
        methods.each do |method|
          delegate method, :to => :controller
        end
      end
      
      # Declare a controller method as a helper.  For example,
      #   helper_method :link_to
      #   def link_to(name, options) ... end
      # makes the link_to controller method available in the view.
      def helper_method(*methods)
        methods.flatten.each do |method|
          master_helper_module.module_eval <<-end_eval
            def #{method}(*args, &block)
              @cell.send(%(#{method}), *args, &block)
            end
          end_eval
        end
      end
    end

    # An instructional note about inheritable attributes: an attribute is
    # inherited at the time of inheritance (class definition). Subsequent
    # changes to a base class's attribute values will not affect subclasses.
    class_inheritable_array :view_paths, :instance_writer => false
    self.view_paths = ActionView::PathSet.new
    class_inheritable_array :view_templates, :instance_writer => false
    self.view_templates = []

    class_inheritable_accessor :allow_forgery_protection
    self.allow_forgery_protection = true

    class_inheritable_accessor :default_template_format
    self.default_template_format = :html

    # Set this to true in a subclass to prevent it from proposing template names
    self.abstract_class = true

    controller_method :params, :session, :request, :logger
    
    attr_accessor :template_format, :controller, :layout, :state
    
    # Each option will be translated into a setter method call. If you want your
    # cell to take an option, consider declaring an attr_accessor. Unrecognized
    # attributes will be silently ignored.
    def initialize(controller, options={})
      self.controller = controller
      self.template_format = self.class.default_template_format
      options.each_pair do |k,v|
        setter = "#{k}="
        send setter, v if respond_to? setter
      end
    end
    
    def cell_name
      self.class.cell_name
    end
    
    # Render the given state (view) to a string.
    def render_state(state, format=nil)
      old_format = template_format
      self.template_format = format = format || template_format
      self.state = state
      content = nil
      results = Benchmark.measure do
        content = if respond_to? state
          send(state) { |state_or_options, localvars|
            st    = state_or_options.is_a?(Symbol) ? state_or_options : state
            lvars = (state_or_options.is_a?(Hash) && state_or_options) || (localvars.is_a?(Hash) && localvars) || {}
            render(st, format,lvars)
          }
        else
          render(state, format)
        end
      end
      Rails.logger.debug "Render #{self.class.name}##{state}: #{results}"
      return content
    ensure
      self.template_format = old_format
      self.state = nil
    end
    helper_method :render_state, :state
    
    protected
    
    # Render the view belonging to the given state. Will raise ActionView::MissingTemplate
    # if it can not find one of the requested view template. Note that this behaviour was
    # introduced in cells 2.3 and replaces the former warning message.
    def render(state, format, local_variables = {})
      view.template_format = format
      render_opts = { :file => find_template(state), :locals => local_variables }
      render_opts[:layout] = find_template(layout) if layout
      view.render(render_opts)
    end
    
    # A Cell::View instance for rendering templates
    def view
      @view ||= returning Cell::View.new(view_paths, {}, @controller) do |v|
        v.cell = self
        v.helper_module = self.class.master_helper_module
      end
    end
    
    # Return the first template (ActionView::Template instance) from the view_templates
    # that exists.
    def find_template(state)
      view.find_template expanded_view_templates_for(state)
    end
    
    # Process the inherited template names, interpolating values using our own instance
    # methods.
    def expanded_view_templates_for(state)
      self.class.view_templates.map { |t| expand_template_name(t, state) }
    end
    
    # Interpolate data from our instance methods into a template name.
    def expand_template_name(template, state)
      eval '"' + template + '"'
    end
  end
end
