module Core
  class Patient < ActiveRecord::Base
    set_table_name "patient"
    set_primary_key "patient_id"
    include Openmrs

    has_one :person, :foreign_key => :person_id, :conditions => {:voided => 0}
    has_many :patient_identifiers, :foreign_key => :patient_id, :dependent => :destroy, :conditions => {:voided => 0}
    has_many :patient_programs, :conditions => {:voided => 0}
    has_many :programs, :through => :patient_programs
    has_many :relationships, :foreign_key => :person_a, :dependent => :destroy, :conditions => {:voided => 0}
    has_many :orders, :conditions => {:voided => 0}

    has_many :program_encounters, :class_name => 'ProgramEncounter',
             :foreign_key => :patient_id, :dependent => :destroy

    has_many :encounters, :conditions => {:voided => 0} do
      def find_by_date(encounter_date)
        encounter_date = Date.today unless encounter_date
        find(:all, :conditions => ["encounter_datetime BETWEEN ? AND ?",
                                   encounter_date.to_date.strftime('%Y-%m-%d 00:00:00'),
                                   encounter_date.to_date.strftime('%Y-%m-%d 23:59:59')
        ]) # Use the SQL DATE function to compare just the date part
      end
    end

    def after_void(reason = nil)
      self.person.void(reason) rescue nil
      self.patient_identifiers.each { |row| row.void(reason) }
      self.patient_programs.each { |row| row.void(reason) }
      self.orders.each { |row| row.void(reason) }
      self.encounters.each { |row| row.void(reason) }
    end

    def name
      "#{self.person.names.first.given_name} #{self.person.names.first.family_name}"
    end

    def national_id
      self.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    end

    def address
      "#{self.person.addresses.first.city_village}" rescue nil
    end

    def age(today = Date.today)
      return nil if self.person.birthdate.nil?

      # This code which better accounts for leap years
      patient_age = (today.year - self.person.birthdate.year) + ((today.month -
          self.person.birthdate.month) + ((today.day - self.person.birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

      # If the birthdate was estimated this year, we round up the age, that way if
      # it is March and the patient says they are 25, they stay 25 (not become 24)
      birth_date=self.person.birthdate
      estimate=self.person.birthdate_estimated==1
      patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1 &&
          today.month < birth_date.month && self.person.date_created.year == today.year) ? 1 : 0
    end

    def gender
      self.person.gender rescue nil
    end

    def age_in_months(today = Date.today)
      years = (today.year - self.person.birthdate.year)
      months = (today.month - self.person.birthdate.month)
      (years * 12) + months
    end

    def allergic_to_sulphur
      status = self.encounters.collect { |e|
        e.observations.find(:last, :conditions => ["concept_id = ?",
                                                   ConceptName.find_by_name("Allergic to sulphur").concept_id]).answer_string rescue nil
      }.compact.flatten.first

      status = "unknown" if status.nil?
    end

    def dpt1
      status = self.encounters.collect { |e|
        e.observations.find(:last, :conditions => ["concept_id = ?",
                                                   ConceptName.find_by_name("Was DPT-HepB-Hib 1 vaccine given at 6 weeks or later?").concept_id]).answer_string rescue nil
      }.compact.flatten.first

      status = "unknown" if status.nil?
    end

    def dpt2
      status = self.encounters.collect { |e|
        e.observations.find(:last, :conditions => ["concept_id = ?",
                                                   ConceptName.find_by_name("Was DPT-HepB-Hib 2 vaccine given at 1 month after first dose?").concept_id]).answer_string rescue nil
      }.compact.flatten.first

      status = "unknown" if status.nil?
    end

    def dpt3
      status = self.encounters.collect { |e|
        e.observations.find(:last, :conditions => ["concept_id = ?",
                                                   ConceptName.find_by_name("Was DPT-HepB-Hib 3 vaccine given at 1 month after second dose?").concept_id]).answer_string rescue nil
      }.compact.flatten.first

      status = "unknown" if status.nil?
    end

    def pcv1
      status = self.encounters.collect { |e|
        e.observations.find(:last, :conditions => ["concept_id = ?",
                                                   ConceptName.find_by_name("PCV 1 vaccine given at 6 weeks or later?").concept_id]).answer_string rescue nil
      }.compact.flatten.first

      status = "unknown" if status.nil?
    end

    def pcv2
      status = self.encounters.collect { |e|
        e.observations.find(:last, :conditions => ["concept_id = ?",
                                                   ConceptName.find_by_name("PCV 2 vaccine given at 1 month after first dose?").concept_id]).answer_string rescue nil
      }.compact.flatten.first

      status = "unknown" if status.nil?
    end

    def pcv3
      status = self.encounters.collect { |e|
        e.observations.find(:last, :conditions => ["concept_id = ?",
                                                   ConceptName.find_by_name("PCV 3 vaccine given at 1 month after second dose?").concept_id]).answer_string rescue nil
      }.compact.flatten.first

      status = "unknown" if status.nil?
    end

    def polio0
      status = self.encounters.collect { |e|
        e.observations.find(:last, :conditions => ["concept_id = ?",
                                                   ConceptName.find_by_name("First polio vaccine at birth").concept_id]).answer_string rescue nil
      }.compact.flatten.first

      status = "unknown" if status.nil?
    end

    def polio1
      status = self.encounters.collect { |e|
        e.observations.find(:last, :conditions => ["concept_id = ?",
                                                   ConceptName.find_by_name("Second polio vaccine at 1.5 months").concept_id]).answer_string rescue nil
      }.compact.flatten.first

      status = "unknown" if status.nil?
    end

    def polio2
      status = self.encounters.collect { |e|
        e.observations.find(:last, :conditions => ["concept_id = ?",
                                                   ConceptName.find_by_name("Third polio vaccine at 2.5 months").concept_id]).answer_string rescue nil
      }.compact.flatten.first

      status = "unknown" if status.nil?
    end

    def polio3
      status = self.encounters.collect { |e|
        e.observations.find(:last, :conditions => ["concept_id = ?",
                                                   ConceptName.find_by_name("Fourth polio vaccine at 3.5 months").concept_id]).answer_string rescue nil
      }.compact.flatten.first

      status = "unknown" if status.nil?
    end


  end
end