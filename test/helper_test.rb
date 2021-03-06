require File.dirname(__FILE__) + '/../../../../test/test_helper'
require File.dirname(__FILE__) + '/testing_helper'

# usually done by rails' autoloading:
require File.dirname(__FILE__) + '/cells/test_cell'

class CellsHelperTest < ActionController::TestCase
  include CellsTestMethods
  
  def test_helper
    cell = HelperUsingCell.new(@controller)

    content = cell.render_state(:state_with_helper_invocation)
    assert_selekt content, "p#stateWithHelperInvocation", "mysterious"
  end
  
  #ActiveSupport::Dependencies.load_paths << RAILS_ROOT + "/vendor/plugins/cells/test/helpers"
  # test if the HelperUsingCellHelper is automatically included:
  
  ## FIXME: currently loading should happen in render_view_for_state, since
  #   there seems to be no automatic mechanism.
  def dont_test_auto_helper
    #ActionController::Base.helpers_dir = RAILS_ROOT + "/vendor/plugins/cells/test/helpers"
    
    Cell::Base.helpers_dir = RAILS_ROOT + "/vendor/plugins/cells/test/helpers"
    setup
    
    cell = HelperUsingCell.new(@controller)

    content = cell.render_state(:state_with_automatic_helper_invocation)
    assert_selekt content, "p#stateWithAutomaticHelperInvocation", "automatic"
  end

  def test_helper_method
    cell = HelperUsingCell.new(@controller)

    content = cell.render_state(:state_with_helper_method_invocation)
    assert_selekt content, "p#stateWithHelperMethodInvocation", "helped by a method"
  end

  def test_helper_with_subclassing
    subclassedcell = HelperUsingSubCell.new(@controller)
    content = subclassedcell.render_state(:state_with_helper_invocation)
    assert_selekt content, "p#stateWithHelperInvocation", "mysterious"
  end

  def test_helper_including_and_cleanup
    # this cell includes a helper, and uses it:
    cell = HelperUsingCell.new(@controller)

    content = cell.render_state(:state_with_helper_invocation)
    assert_selekt content, "p#stateWithHelperInvocation", "mysterious"

    # this cell doesn't include the helper, but uses it anyway, which should
    # produce an error:

    cell = MyTestCell.new(@controller)
#    assert_raises (NameError) do
     assert_raises (ActionView::TemplateError) do
      cell.render_state(:state_with_not_included_helper_method)
    end
  end
  
  
  def test_helpers_included_on_different_inheritance_levels
    cell = TwoHelpersIncludingCell.new(@controller)

    c = cell.render_state(:state_with_helper_invocation)
    assert_selekt c, "p#stateWithHelperInvocation", "mysterious"
    
    c = cell.render_state(:state_using_another_helper)
    assert_selekt c, "p#stateUsingAnotherHelper", "senseless"
  end
  
  
  def test_application_helper
    cell = HelperUsingCell.new(@controller)

    c = cell.render_state(:state_using_application_helper)
    assert_selekt c, "p#stateUsingApplicationHelper", "global"
  end
end


module ApplicationHelper
  def application_helper_method
    "global"
  end
end


module CellsTestHelper
  def a_mysterious_helper_method
    "mysterious"
  end
end


module AnotherHelper
  def senseless_helper_method
    "senseless"
  end
end


class HelperUsingCell < Cell::Base
  helper CellsTestHelper
  
  def state_with_helper_invocation
  end

  def state_with_automatic_helper_invocation
  end

  def state_with_helper_method_invocation
  end
  
  def state_using_application_helper
  end

protected

  def my_helper_method
    "helped by a method"
  end

  helper_method :my_helper_method
end

class TwoHelpersIncludingCell < HelperUsingCell
  
  helper AnotherHelper
  
  def state_using_another_helper
  end
end


class HelperUsingSubCell < HelperUsingCell
end
