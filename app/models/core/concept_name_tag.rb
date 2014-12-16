module Core
  class ConceptNameTag < ActiveRecord::Base
    set_table_name :concept_name_tag
    set_primary_key :concept_name_tag_id
    include Core::Openmrs
    has_many :concept_name_tag_map, :class_name => 'Core::ConceptNameTagMap' # no default scope
    has_many :concept_name, :class_name => 'Core::ConceptName', :through => :concept_name_tag_map
  end
end

