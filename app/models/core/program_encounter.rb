module Core
  class ProgramEncounter < ActiveRecord::Base
    set_table_name :program_encounter
    set_primary_key :program_encounter_id
    include Core::Openmrs

    named_scope :current, :conditions => ['DATE(date_time) = CURRENT_DATE()']

    has_many :program_encounter_types, :class_name => 'Core::ProgramEncounterDetail',
             :foreign_key => :program_encounter_id, :dependent => :destroy, :conditions => ["COALESCE(program_encounter_details.voided, 0) = ?", 0]

    belongs_to :patient, :class_name => 'Core::Patient', :foreign_key => :patient_id, :dependent => :destroy

    belongs_to :program, :class_name => 'Core::Program', :foreign_key => :program_id, :dependent => :destroy

    cattr_accessor :current_date

    def to_s
      if !self.program.concept.shortname.blank?
        "#{self.program.concept.shortname}"
      else
        "#{self.program.concept.fullname}"
      end
    end

  end
end