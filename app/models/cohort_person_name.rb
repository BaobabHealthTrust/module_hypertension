class CohortPersonName < ActiveRecord::Base
  set_table_name "person_name"
  set_primary_key "person_name_id"

  belongs_to :person, :class_name => 'CohortPerson', :foreign_key => :person_id, :conditions => {:voided => 0}
  
end