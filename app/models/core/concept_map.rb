module Core
  class ConceptMap < ActiveRecord::Base
    set_table_name :concept_map
    set_primary_key :concept_map_id
    include Core::Openmrs
    belongs_to :concept, :class_name => 'Core::Concept', :conditions => {:retired => 0}
    belongs_to :concept_source, :class_name => 'Core::ConceptSource', :foreign_key => :source, :conditions => {:voided => 0}
  end
end