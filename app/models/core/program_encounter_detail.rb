module Core
  class ProgramEncounterDetail < ActiveRecord::Base
    set_table_name :program_encounter_details
    set_primary_key :id
    include Core::Openmrs

    belongs_to :program_encounter, :class_name => 'Core::ProgramEncounter', :foreign_key => :program_encounter_id, :dependent => :destroy

    belongs_to :encounter, :class_name => 'Core::Encounter', :foreign_key => :encounter_id, :dependent => :destroy

    def void
      self.update_attribute("voided", 1)
    end

  end
end