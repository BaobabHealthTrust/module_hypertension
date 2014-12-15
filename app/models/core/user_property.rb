module Core
  class UserProperty < ActiveRecord::Base
    set_table_name "user_property"
    set_primary_keys :user_id, :property
    include Core::Openmrs
    belongs_to :user, :class_name => 'Core::User', :foreign_key => :user_id, :conditions => {:voided => 0}
  end
end