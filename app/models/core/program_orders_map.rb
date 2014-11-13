module Core
  class ProgramOrdersMap < ActiveRecord::Base
    set_table_name "program_orders_map"
    set_primary_key "program_orders_map_id"
    include Core::Openmrs
    belongs_to :program, :class_name => 'Core::Program', :conditions => {:retired => 0}
    belongs_to :concept, :class_name => 'Core::Concept', :conditions => {:retired => 0}
  end
end