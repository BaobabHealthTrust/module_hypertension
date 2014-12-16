module Core
  class PersonAttribute < ActiveRecord::Base
    set_table_name "person_attribute"
    set_primary_key "person_attribute_id"
    include Core::Openmrs

    belongs_to :type, :class_name => "Core::PersonAttributeType", :foreign_key => :person_attribute_type_id, :conditions => {:retired => 0}
    belongs_to :person, :class_name => 'Core::Person', :foreign_key => :person_id, :conditions => {:voided => 0}
  end
end