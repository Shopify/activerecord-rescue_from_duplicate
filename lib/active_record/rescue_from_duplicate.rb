require 'active_support'
require 'active_support/core_ext/object/try'
require "active_record/rescue_from_duplicate/version"
require 'active_record/rescue_from_duplicate/extension'

module Activerecord
  module RescueFromDuplicate
  end
end


ActiveSupport.on_load(:active_record) do
  ::ActiveRecord::Base.send :include, ActiveRecord::RescueFromDuplicate::Extension
end
