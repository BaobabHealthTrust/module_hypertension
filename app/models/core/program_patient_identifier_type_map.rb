module Core
  class ProgramPatientIdentifierTypeMap < ActiveRecord::Base
    set_table_name "program_patient_identifier_type_map"
    set_primary_key "program_patient_identifier_type_map_id"
    include Core::Openmrs
    belongs_to :program, :class_name => 'Core::Program', :conditions => {:retired => 0}
    belongs_to :patient_identifier_type, :class_name => 'Core::PatientIdentifierType', :conditions => {:retired => 0}
  end
end