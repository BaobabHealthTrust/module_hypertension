module Core
  class User < ActiveRecord::Base

    set_table_name :users
    set_primary_key :user_id
    include Core::Openmrs

    has_many :user_properties, :class_name => 'Core::UserProperty', :foreign_key => :user_id # no default scope

    cattr_accessor :current

  end
end