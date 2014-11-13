module Core
  class Program < ActiveRecord::Base
    set_table_name "program"
    set_primary_key "program_id"
    include Core::Openmrs
    belongs_to :concept, :class_name => 'Core::Concept', :conditions => {:retired => 0}
    has_many :patient_programs, :class_name => 'Core::PatientProgram', :conditions => {:voided => 0}
    has_many :program_workflows, :class_name => 'Core::ProgramWorkflow', :conditions => {:retired => 0}
    has_many :program_workflow_states, :class_name => 'Core::ProgramWorkflowState', :through => :program_workflows

    has_many :program_encounters, :class_name => 'Core::ProgramEncounter', :foreign_key => :program_id

    # Actually returns +Concept+s of suitable +Regimen+s for the given +weight+
    # and this +Program+
    def regimens(weight=nil)
      Regimen.program(program_id).criteria(weight).all(
          :select => 'concept_id',
          :group => 'concept_id, program_id',
          :include => :concept, :order => 'regimen_id').map(&:concept)
    end
  end
end