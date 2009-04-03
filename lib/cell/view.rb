module Cell
  class View < ::ActionView::Base
    attr_accessor :cell
    
    # Finds the first partial from partial_names that exists.
    def find_template(partial_names)
      missing_template_exception = nil
      partial_names.each do |name|
        # we need to catch MissingTemplate, since we want to try for all possible
        # family views.
        begin
          partial = view_paths.find_template(name, template_format)
          return partial if partial
        rescue ::ActionView::MissingTemplate => e
          missing_template_exception ||= e
        end
      end
      raise missing_template_exception
    end
    
    def helper_module=(mod)
      class_eval { include mod }
    end
  end
end
