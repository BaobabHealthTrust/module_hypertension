module Core
  class ProgramWorkflow < ActiveRecord::Base
    set_table_name "program_workflow"
    set_primary_key "program_workflow_id"
    include Core::Openmrs
    belongs_to :program, :class_name => 'Core::Program', :conditions => {:retired => 0}
    belongs_to :concept, :class_name => 'Core::Concept', :conditions => {:retired => 0}
    has_many :program_workflow_states, :class_name => 'Core::ProgramWorkflowState', :conditions => {:retired => 0}
  end
end