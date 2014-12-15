module Core
  class ProgramWorkflowState < ActiveRecord::Base
    set_table_name "program_workflow_state"
    set_primary_key "program_workflow_state_id"
    include Core::Openmrs
    belongs_to :program_workflow, :class_name => 'Core::ProgramWorkflow', :conditions => {:retired => 0}
    belongs_to :concept, :class_name => 'Core::Concept', :conditions => {:retired => 0}

    def self.find_state(state_id)
      self.find_by_sql(["SELECT * FROM `program_workflow_state` WHERE (`program_workflow_state`.`program_workflow_state_id` = ?)", state_id]).first
    end
  end
end