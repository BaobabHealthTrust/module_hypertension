module Core
  class ProgramRelationshipTypeMap < ActiveRecord::Base
    set_table_name "program_relationship_type_map"
    set_primary_key "program_relationship_type_map_id"
    include Core::Openmrs
    belongs_to :program, :class_name => 'Core::Program', :conditions => {:retired => 0}
    belongs_to :relationship_type, :class_name => 'Core::RelationshipType', :conditions => {:retired => 0}
  end
end