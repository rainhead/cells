require File.dirname(__FILE__) + '/../../../../test/test_helper'
require File.dirname(__FILE__) + '/testing_helper'

# this would usually happen by rails' autoloading -
# anyway, we don't test loading but rendering in this file.
require File.dirname(__FILE__) + '/cells/cells_test_one_cell'
require File.dirname(__FILE__) + '/cells/cells_test_two_cell'
require File.dirname(__FILE__) + '/cells/simple_cell'
require File.dirname(__FILE__) + '/cells/test_cell'

Cell::Base.add_view_path "vendor/plugins/cells/test/cells"

module Some
  class Cell < Cell::Base
  end
end

class JustOneViewCell < Cell::Base
  def some_state
    return
  end

  def view_for_state(state)
    CellsTestMethods.views_path + "just_one_view.html.erb"
  end
end





class CellContainedInPlugin < Cell::Base
  def some_view
  end  
end


# fixture for various tests -----------------------------------
# views are located in cells/test/cells/my_test/
class MyTestCell < Cell::Base
  
  def direct_output
    "<h9>this state method doesn't render a template but returns a string, which is great!</h9>"
  
  end
end

# fixtures for view inheritance -------------------------------
# views are located in cells/test/cells/my_mother_cell/
class MyMotherCell < Cell::Base
  attr_accessor :message
  helper_method :message
  
  def hello
    self.message = "hello, kid!"
    nil
  end
  def bye
    self.message = "bye, you!"
    nil
  end
end

# views are located in cells/test/cells/my_child_cell/
class MyChildCell < MyMotherCell
  def hello
    self.message = "hello, mom!"
    nil
  end
  # view is inherited and located in cells/test/cells/my_mother_cell/bye.html.erb
  def bye
    self.message = "bye, mom!"
    nil
  end
end


module ReallyModule
  class NestedCell < Cell::Base
    # view: cells/test/cells/really_module/nested_cell/happy_state.html.erb
    def happy_state
    end
  end
end


class CellsTest < ActionController::TestCase
  include CellsTestMethods
  
  Cell::Base.add_view_path "vendor/plugins/cells/test/cells"
  ### FIXME:
  #Cell::View.warn_cache_misses = true
  

  def test_controller_render_methods
    get :call_render_cell_with_strings  # render_cell("test", "state")
    assert_response :success
    assert_tag :tag => "h9"

    get :call_render_cell_with_syms
    assert_response :success
    assert_tag :tag => "h9"
  end
  
  
  # test simple rendering cycle -------------------------------------------------
  
  # ok
  def test_render_state_which_returns_a_string
    cell = MyTestCell.new(@controller)
    
    c= cell.render_state(:direct_output)
    assert_kind_of String, c
    assert_selekt c, "h9"
    
    #assert_raises (NoMethodError) { cell.render_state("non_existing_state") }
  end
  
  
  def test_render_state_with_missing_view
    cell = MyTestCell.new(@controller)
    ### TODO: production <-> development/test context.
    
    assert_raises ActionView::MissingTemplate do
      c = cell.render_state(:missing_view)
    end
  end
  
  
  # test partial rendering ------------------------------------------------------
  
  # ok
  def test_not_existing_partial
    t = MyTestCell.new(@controller)
    assert_raises ActionView::TemplateError do
      t.render_state(:view_containing_nonexistant_partial)
    end
  end
  
  # ok
  def test_broken_partial
    t = MyTestCell.new(@controller)
    assert_raises ActionView::TemplateError do
      t.render_state(:view_containing_broken_partial)
    end
  end
  
  # ok
  def test_render_state_within_partial
    cell = MyTestCell.new(@controller)
    c = cell.render_state(:view_containing_partial)
    assert_selekt c, "#partialContained>#partial"
  end
  
  # test view inheritance -------------------------------------------------------
  
  def test_view_templates
    t = MyChildCell.new(@controller)
    t.state = :bye
    t.class_eval { public :view_templates }
    p = t.view_templates
    assert_equal "my_child/bye", p.first
    assert_equal "my_mother/bye", p.last
  end
  
  
  def test_render_state_on_child_where_child_view_exists
    cell = MyChildCell.new(@controller)
    c = cell.render_state(:hello)
    assert_selekt c, "#childHello", "hello, mom!"
  end
  
  def test_render_state_on_child_where_view_is_inherited_from_mother
    cell = MyChildCell.new(@controller)
    c = cell.render_state(:bye)
    assert_selekt c, "#motherBye", "bye, mom!"
  end
  
  
  # test Cell::View -------------------------------------------------------------
  
  def test_find_template
    t = MyChildCell.new @controller
    t.state = :bye
    t.class_eval { public :find_template }
    tpl = t.find_template
    assert_equal "my_mother/bye.html.erb", tpl.path
  end
  
  
  # view for :instance_view is provided directly by #view_for_state.
  def test_view_for_state
    t = CellsTestOneCell.new(@controller)
    c = t.render_state(:instance_view)
    assert_selekt c, "#renamedInstanceView"
  end
  

  ### API test (unit) -----------------------------------------------------------
  def test_cell_name
    cell_one = CellsTestOneCell.new(@controller)

    assert_equal cell_one.cell_name, "cells_test_one"
    assert_equal CellsTestOneCell.cell_name, "cells_test_one"
  end
  
  def test_class_from_cell_name
    assert_equal Cell::Base.class_from_cell_name("cells_test_one"), CellsTestOneCell
  end


  def test_new_directory_hierarchy
    cell = ReallyModule::NestedCell.new(@controller)
    view = cell.render_state(:happy_state)
    @response.body = view

    assert_select "#happyStateView"
  end

  # Thanks to Fran Pena who made us aware of this bug and contributed a patch.
  def test_i18n_support
    orig_locale = I18n.locale
    I18n.locale = :en
    
    t = MyTestCell.new(@controller)
    c = t.render_state(:view_with_explicit_english_translation)
    
    I18n.locale = orig_locale   # cleanup before we mess up!
    
    # the view "view_with_explicit_english_translation.en" exists, check if
    # rails' i18n found it:
    assert_selekt c, "#defaultTranslation", 0
    assert_selekt c, "#explicitEnglishTranslation"
  end
  
  
  def test_modified_view_finding_for_testing    
    t = MyTestCell.new(@controller)
    c = t.render_state(:view_in_local_test_views_dir)
    assert_selekt c, "#localView"
  end
  
  
  def test_params_in_a_cell_state
    @controller.params = {:my_param => "value"}
    t = MyTestCell.new(@controller)
    c = t.render_state(:state_using_params)
    assert_equal c, "value"
  end
  
  ### functional tests: ---------------------------------------------------------

  def test_link_to_in_view
    get :render_state_with_link_to

    assert_response :success
    assert_select "a", "bla"
  end

end
