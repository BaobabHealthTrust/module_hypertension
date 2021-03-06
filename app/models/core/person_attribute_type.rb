module Core
  class PersonAttributeType < ActiveRecord::Base
    set_table_name :person_attribute_type
    set_primary_key :person_attribute_type_id
    include Core::Openmrs
    has_many :person_attributes, :class_name => 'Core::PersonAttribute', :conditions => {:voided => 0}
  end
end