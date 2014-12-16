module Core
  class ConceptNameTagMap < ActiveRecord::Base
    set_table_name :concept_name_tag_map
    set_primary_key :concept_name_tag_map_id
    include Core::Openmrs
    belongs_to :tag, :foreign_key => :concept_name_tag_id, :class_name => 'Core::ConceptNameTag', :conditions => {:voided => 0}
    belongs_to :concept_name_tag, :class_name => 'Core::ConceptNameTag', :conditions => {:voided => 0}
    belongs_to :concept_name, :class_name => 'Core::ConceptName', :conditions => {:retired => 0}
  end
end

