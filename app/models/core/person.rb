module Core
  class Person < ActiveRecord::Base
    set_table_name "person"
    set_primary_key "person_id"
    include Core::Openmrs

    cattr_accessor :session_datetime
    cattr_accessor :migrated_datetime
    cattr_accessor :migrated_creator
    cattr_accessor :migrated_location

    has_one :patient, :class_name => 'Core::Patient', :foreign_key => :patient_id, :dependent => :destroy, :conditions => {:voided => 0}
    has_many :names, :class_name => 'Core::PersonName', :foreign_key => :person_id, :dependent => :destroy, :order => 'person_name.preferred DESC', :conditions => {:voided => 0}
    has_many :addresses, :class_name => 'Core::PersonAddress', :foreign_key => :person_id, :dependent => :destroy, :order => 'person_address.preferred DESC', :conditions => {:voided => 0}
    has_many :relationships, :class_name => 'Core::Relationship', :foreign_key => :person_a, :conditions => {:voided => 0}
    has_many :person_attributes, :class_name => 'Core::PersonAttribute', :foreign_key => :person_id, :conditions => {:voided => 0}
    has_many :observations, :class_name => 'Core::Observation', :foreign_key => :person_id, :dependent => :destroy, :conditions => {:voided => 0} do
      def find_by_concept_name(name)
        concept_name = Core::ConceptName.find_by_name(name)
        find(:all, :conditions => ['concept_id = ?', concept_name.concept_id]) rescue []
      end
    end

    def after_void(reason = nil)
      self.patient.void(reason) rescue nil
      self.names.each { |row| row.void(reason) }
      self.addresses.each { |row| row.void(reason) }
      self.relationships.each { |row| row.void(reason) }
      self.person_attributes.each { |row| row.void(reason) }
      # We are going to rely on patient => encounter => obs to void those
    end

  end
end