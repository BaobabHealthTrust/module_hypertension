module Core
  class EncounterType < ActiveRecord::Base
    set_table_name :encounter_type
    set_primary_key :encounter_type_id
    include Core::Openmrs
    has_many :encounters, :class_name => 'Core::Encounter', :conditions => {:voided => 0}
  end
end