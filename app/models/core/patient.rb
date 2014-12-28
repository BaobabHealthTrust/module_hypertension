module Core
  class Patient < ActiveRecord::Base
    set_table_name "patient"
    set_primary_key "patient_id"
    include Core::Openmrs

    has_one :person, :class_name => 'Core::Person', :foreign_key => :person_id, :conditions => {:voided => 0}
    has_many :patient_identifiers, :class_name => 'Core::PatientIdentifier', :foreign_key => :patient_id, :dependent => :destroy, :conditions => {:voided => 0}
    has_many :patient_programs, :class_name => 'Core::PatientProgram', :conditions => {:voided => 0}
    has_many :programs, :class_name => 'Core::Program', :through => :patient_programs
    has_many :relationships, :class_name => 'Core::Relationship', :foreign_key => :person_a, :dependent => :destroy, :conditions => {:voided => 0}
    has_many :orders, :class_name => 'Core::Order', :conditions => {:voided => 0}

    has_many :program_encounters, :class_name => 'Core::ProgramEncounter', :class_name => 'Core::ProgramEncounter', :foreign_key => :patient_id, :dependent => :destroy

    has_many :encounters, :class_name => 'Core::Encounter', :conditions => {:voided => 0} do
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
      self.patient_identifiers.find_by_identifier_type(Core::PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
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
                                                   Core::ConceptName.find_by_name("Allergic to sulphur").concept_id]).answer_string rescue nil
      }.compact.flatten.first

      status = "unknown" if status.nil?
    end

    def national_id_with_dashes
      id = national_id
      length = id.length
      case length
        when 13
          id[0..4] + "-" + id[5..8] + "-" + id[9..-1] rescue id
        when 9
          id[0..2] + "-" + id[3..6] + "-" + id[7..-1] rescue id
        when 6
          id[0..2] + "-" + id[3..-1] rescue id
        else
          id
      end
    end

   def eligible_for_htn_screening(date = Date.today)
    threshold = CoreService.get_global_property_value("htn.screening.age.threshold").to_i

    if self.age(date) >= threshold

     htn_program = Core::Program.find_by_name("HYPERTENSION PROGRAM")

     patient_program = enrolled_on_program(htn_program.id,date,false)

     if patient_program.blank?
      #When patient has no HTN program
      last_check = last_bp_readings(date)

      if last_check.blank?
       return true #patient has never had their BP checked
      elsif ((last_check['SBP'].to_i >= 140 || last_check['DBP'].to_i >= 90))
       return true #patient had high BP readings at last visit
      elsif((date.to_date - last_check.max_date.to_date).to_i >= 365 )
       return true # 1 Year has passed since last check
      else
       return false
      end
     else
      #Get plan
      plan_concept = Core::Concept.find_by_name('Plan').id
      plan = Core::Observation.find(:last,:conditions => ["person_id = ? AND concept_id = ?
                                               AND obs_datetime <= ?",self.id,plan_concept,
                                               date.to_date.strftime('%Y-%m-%d 23:59:59')],
                                              :order => "obs_datetime DESC")
      if plan.blank?
       return true
      else
       if plan.value_text.match(/ANNUAL/i)
        if ((date.to_date - plan.obs_datetime.to_date).to_i >= 365 )
         return true #patient on annual screening and time has elapsed
        else
         return false #patient was screen but a year has not passed
        end
       else
        return true #patient requires active screening
       end
      end

     end
    else
     return false
    end

   end

   def bp_normal()
    diastolic = Core::Observation.find(:last,:conditions => ["person_id = ? AND concept_id = ? AND obs_datetime = ?",
                                              self.id,Core::Concept.find_by_name("diastolic blood pressure").concept_id,
                                              Date.today])
    systolic = Core::Observation.find(:last,:conditions => ["person_id = ? AND concept_id = ? AND obs_datetime = ?",
                                             self.id,Core::Concept.find_by_name("systolic blood pressure").concept_id,
                                             Date.today])
    if (diastolic.blank? || systolic.blank?)
     raise "Patient has no BP measurements".to_s
    else
     if (diastolic.value_text.to_i >= 90 || systolic.value_text.to_i >= 140)
       false
     else
      true
     end
    end
   end

   def on_hypertensive_medicine()

   end

   def bp_management_trail(date = Date.today)
    visits = []

    sbp_concept = Core::Concept.find_by_name('Systolic blood pressure').id
    dbp_concept = Core::Concept.find_by_name('Diastolic blood pressure').id
    plan_concept = Core::Concept.find_by_name('Plan').id

    records = Core::Observation.find_by_sql("SELECT  DISTINCT o.encounter_id,o.person_id,o.obs_datetime,
                                       (SELECT value_numeric FROM obs WHERE encounter_id = o.encounter_id
                                       AND concept_id = #{sbp_concept} AND person_id = o.person_id AND voided = 0 LIMIT 1) AS SBP,
                                       (SELECT value_numeric FROM obs WHERE encounter_id = o.encounter_id
                                       AND concept_id = #{dbp_concept} AND person_id = o.person_id AND voided = 0 LIMIT 1) AS DBP,
                                       (SELECT value_text FROM obs WHERE concept_id = #{plan_concept} AND person_id = o.person_id
                                       AND obs_datetime BETWEEN DATE_FORMAT(obs_datetime, '%Y-%m-%d 00:00:00') AND
                                       DATE_FORMAT(obs_datetime, '%Y-%m-%d 23:59:59') AND voided = 0 LIMIT 1) AS plan
                                       FROM obs as o WHERE o.person_id = #{self.id} AND o.voided = 0 AND obs_datetime <=
                                       '#{date.to_date.strftime('%Y-%m-%d 23:59:59')}' HAVING SBP IS NOT NULL
                                       AND DBP IS NOT NULL ORDER BY o.obs_datetime DESC").each do |record|
     visits << {"date" => record.obs_datetime.strftime("%d-%b-%Y"), "systolic" => record["SBP"],
                "diastolic" => record["DBP"], "plan" => (record["plan"].blank? ? "" : record["plan"]), "drugs" => "None"}
    end

    return visits
   end

   def current_bp_drugs(date = Date.today)
      medication_concept       = ConceptName.find_by_name("HYPERTENSION DRUGS").concept_id
      drug_concept_ids = ConceptSet.all(:conditions => ['concept_set = ?', medication_concept]).map(&:concept_id)
      drugs = Drug.all(:conditions => ["concept_id IN (?)", drug_concept_ids])

      result = DrugOrder.all(:select => ["drug_inventory_id"], :joins => "
                INNER JOIN orders ON orders.order_id = drug_order.order_id AND orders.patient_id = #{self.id}
                INNER JOIN encounter ON orders.encounter_id = encounter.encounter_id",
                     :conditions => ["drug_inventory_id IN (?) AND DATE(encounter.encounter_datetime) <= ?",
                                     drugs.map(&:drug_id), date]).map(&:drug_inventory_id).uniq

      prev_date = DrugOrder.last(:select => ["encounter_datetime"], :joins => "
                INNER JOIN orders ON orders.order_id = drug_order.order_id AND orders.patient_id = #{self.id}
                INNER JOIN encounter ON orders.encounter_id = encounter.encounter_id",
                               :conditions => ["drug_inventory_id IN (?) AND DATE(encounter.encounter_datetime) <= ?",
                                               drugs.map(&:drug_id), date]).encounter_datetime.to_date rescue nil

      concept_id = ConceptName.find_by_name("Amount of drug remaining at home").concept_id
      result += Observation.all(:select => ["value_drug"],
                               :conditions => ["person_id = ? AND concept_id = ?
                                                AND DATE(obs_datetime) = ? AND value_drug NOT IN (?)",
                                                self.id, concept_id, prev_date.to_date, result
                  ]).map(&:value_drug) rescue nil
     result = result.collect{|drug_id| Drug.find(drug_id).name}
   end

   def enrolled_on_program( program_id, date = DateTime.now, create = false)
    program = Core::PatientProgram.find(:last,:conditions => ["patient_id = ? AND
                                               program_id = ? AND date_enrolled <= ?",self.id,program_id,
                                               date.strftime("%Y-%m-%d 23:59:59")])

    if program.blank? and create
     ActiveRecord::Base.transaction do
      program = Core::PatientProgram.create({:program_id => program_id, :date_enrolled => date,
                                             :patient_id => self.id})
      alive_state = Core::ProgramWorkflowState.find(:first, :conditions => ["program_workflow_id = ? AND concept_id = ?",
                                                                            Core::ProgramWorkflow.find(:first, :conditions => ["program_id = ?", program_id]).id,
                                                                            Core::Concept.find_by_name("Alive").id]).id
      Core::PatientState.create(:patient_program_id => program.id, :start_date => date,:state => alive_state )
     end
    end

    program
   end


    def current_bp(date = Date.today)
      encounter_id = self.encounters.last(:conditions => ["encounter_type = ? AND DATE(encounter_datetime) = ?",
                                                          Core::EncounterType.find_by_name("VITALS").id, date.to_date]).id rescue nil

      [(Core::Observation.last(:conditions => ["encounter_id = ? AND concept_id = ?", encounter_id,
                                         Core::ConceptName.find_by_name("SYSTOLIC BLOOD PRESSURE").concept_id]).answer_string.to_i rescue nil),
       (Core::Observation.last(:conditions => ["encounter_id = ? AND concept_id = ?", encounter_id,
                                         Core::ConceptName.find_by_name("DIASTOLIC BLOOD PRESSURE").concept_id]).answer_string.to_i rescue nil)
      ]
    end

   def last_bp_readings(date)
    sbp_concept = Core::Concept.find_by_name('Systolic blood pressure').id
    dbp_concept = Core::Concept.find_by_name('Diastolic blood pressure').id

    return Core::Observation.find_by_sql("SELECT o.person_id, (SELECT MAX(obs_datetime) FROM obs
                                         WHERE person_id = o.person_id AND voided = 0 AND
                                         obs_datetime <= '#{date.to_date.strftime('%Y-%m-%d 23:59:59')}' AND
                                         concept_id in (#{dbp_concept},#{sbp_concept})) AS max_date,
                                         (SELECT COALESCE(value_numeric,0) FROM obs WHERE obs_datetime = max_date
                                         AND concept_id = #{sbp_concept} AND person_id = o.person_id LIMIT 1) AS SBP,
                                         (SELECT COALESCE(value_numeric,0) FROM obs WHERE obs_datetime = max_date
                                         AND concept_id = #{dbp_concept} AND person_id = o.person_id LIMIT 1) AS DBP
                                         FROM obs as o WHERE o.person_id =#{self.id} HAVING max_date IS NOT NULL").first rescue nil
   end

  end
end
