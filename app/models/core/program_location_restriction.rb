module Core
  class ProgramLocationRestriction < ActiveRecord::Base
    set_table_name "program_location_restriction"
    set_primary_key "program_location_restriction_id"
    include Core::Openmrs
    belongs_to :program, :class_name => 'Core::Program', :conditions => {:retired => 0}
    belongs_to :location, :class_name => 'Core::Location', :conditions => {:retired => 0}

    def filter_programs(programs)
      programs.reject { |program| self.program_id == program.program_id }
    end

    def filter_patient_identifiers(identifiers)
      type_map = Core::ProgramPatientIdentifierTypeMap.all(:conditions => {:program_id => self.program_id})
      type_map = type_map.map { |t| t.patient_identifier_type_id }
      identifiers.reject { |ident| type_map.include?(ident.identifier_type) }
    end

    def filter_relationships(relationships)
      type_map = Core::ProgramRelationshipTypeMap.all(:conditions => {:program_id => self.program_id})
      type_map = type_map.map { |t| t.relationship_type_id }
      relationships.reject { |rel| type_map.include?(rel.relationship) }
    end

    def filter_orders(orders)
      type_map = Core::ProgramOrdersMap.all(:conditions => {:program_id => self.program_id})
      type_map = type_map.map { |t| t.concept_id }
      orders.reject { |order| type_map.include?(order.concept_id) }
    end

    def filter_encounters(encounters)
      type_map = Core::ProgramEncounterTypeMap.all(:conditions => {:program_id => self.program_id})
      type_map = type_map.map { |t| t.encounter_type_id }
      encounters.reject { |enc| type_map.include?(enc.encounter_type) }
    end
  end
end