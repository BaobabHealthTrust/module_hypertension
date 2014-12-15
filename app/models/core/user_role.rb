module Core
  class UserRole < ActiveRecord::Base
    set_table_name :user_role
    set_primary_keys :role, :user_id
    include Core::Openmrs
    belongs_to :user, :class_name => 'Core::User', :foreign_key => :user_id, :conditions => {:retired => 0}
  end
end