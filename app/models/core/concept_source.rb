module Core
  class ConceptSource < ActiveRecord::Base
    set_table_name :concept_source
    set_primary_key :concept_source_id
    include Core::Openmrs
    has_many :concept_maps, :class_name => 'Core::ConceptMap', :foreign_key => :source # no default scope
    has_many :concepts, :class_name => 'Core::Concept', :through => :concept_maps
  end
end