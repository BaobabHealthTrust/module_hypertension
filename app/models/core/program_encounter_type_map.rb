module Core
  class ProgramEncounterTypeMap < ActiveRecord::Base
    set_table_name "program_encounter_type_map"
    set_primary_key "program_encounter_type_map_id"
    include Core::Openmrs
    belongs_to :program, :class_name => 'Core::Program', :conditions => {:retired => 0}
    belongs_to :encounter_type, :class_name => 'Core::EncounterType', :conditions => {:retired => 0}
  end
end