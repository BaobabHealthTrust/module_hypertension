class CohortPerson < ActiveRecord::Base
  set_table_name "person"
  set_primary_key "person_id"

  has_many :names, :class_name => 'CohortPersonName', :foreign_key => :person_id,
    :dependent => :destroy, :order => 'person_name.preferred DESC',
    :conditions => {:voided => 0}

end