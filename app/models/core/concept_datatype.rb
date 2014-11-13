module Core
  class ConceptDatatype < ActiveRecord::Base
    set_table_name :concept_datatype
    set_primary_key :concept_datatype_id
    include Core::Openmrs
    has_many :concepts, :class_name => 'Core::Concept', :foreign_key => :datatype_id, :conditions => {:retired => 0}
    belongs_to :user, :class_name => 'Core::User', :foreign_key => :user_id, :conditions => {:voided => 0}
  end
end