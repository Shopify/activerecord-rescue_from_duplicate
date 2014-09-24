require 'active_support'
require 'active_support/core_ext/object/try'
require "rescue_from_duplicate/active_record/version"

module RescueFromDuplicate
  module ActiveRecord
  end
end

require 'rescue_from_duplicate/active_record/extension'
require 'rescue_from_duplicate/rescuer'

ActiveSupport.on_load(:active_record) do
  ::ActiveRecord::Base.send :include, RescueFromDuplicate::ActiveRecord::Extension
end
