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
      sbp_threshold = CoreService.get_global_property_value("htn_systolic_threshold").to_i
      dbp_threshold = CoreService.get_global_property_value("htn_diastolic_threshold").to_i

      if (self.age(date) >= threshold || self.programs.map{|x| x.name}.include?("HYPERTENSION PROGRAM"))

        htn_program = Core::Program.find_by_name("HYPERTENSION PROGRAM")

        patient_program = enrolled_on_program(htn_program.id,date,false)

        if patient_program.blank?
          #When patient has no HTN program
          last_check = last_bp_readings(date)

          if last_check.blank?
            return true #patient has never had their BP checked
          elsif ((last_check[:sbp].to_i >= sbp_threshold || last_check[:dbp].to_i >= dbp_threshold))
            return true #patient had high BP readings at last visit
          elsif((date.to_date - last_check[:max_date].to_date).to_i >= 365 )
            return true # 1 Year has passed since last check
          else
            return false
          end
        else
          #Get plan

          plan_concept = Core::Concept.find_by_name('Plan').id
          plan = Core::Observation.find(:first,:conditions => ["person_id = ? AND concept_id = ?
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
      sbp_threshold = CoreService.get_global_property_value("htn_systolic_threshold").to_i
      dbp_threshold = CoreService.get_global_property_value("htn_diastolic_threshold").to_i

      diastolic = Core::Observation.find(:last,:conditions => ["person_id = ? AND concept_id = ? AND obs_datetime = ?",
          self.id,Core::Concept.find_by_name("diastolic blood pressure").concept_id,
          Date.today])
      systolic = Core::Observation.find(:last,:conditions => ["person_id = ? AND concept_id = ? AND obs_datetime = ?",
          self.id,Core::Concept.find_by_name("systolic blood pressure").concept_id,
          Date.today])
      if (diastolic.blank? || systolic.blank?)
        raise "Patient has no BP measurements".to_s
      else
        if (diastolic.value_text.to_i >= dbp_threshold || systolic.value_text.to_i >= sbp_threshold)
          false
        else
          true
        end
      end
    end

    def on_hypertensive_medicine()

    end

    def patient_blood_presure(date = Date.today)
      sbp_concept = Core::Concept.find_by_name('Systolic blood pressure').id
      dbp_concept = Core::Concept.find_by_name('Diastolic blood pressure').id
      plan_concept = Core::Concept.find_by_name('Plan').id
      
      sbp_data = {}
      dbp_data = {}
      plan_data = {}
      visits = []
      
      sbp_obs = Core::Observation.find_by_sql("
        SELECT * FROM obs WHERE concept_id = #{sbp_concept} AND person_id = #{self.id} AND voided = 0
        AND obs_datetime <= '#{date.to_date.strftime('%Y-%m-%d 23:59:59')}'
        ")

      dbp_obs = Core::Observation.find_by_sql("
        SELECT * FROM obs WHERE concept_id = #{dbp_concept} AND person_id = #{self.id} AND voided = 0
        AND obs_datetime <= '#{date.to_date.strftime('%Y-%m-%d 23:59:59')}'
        ")

      plan_obs = Core::Observation.find_by_sql("
        SELECT * FROM obs WHERE concept_id = #{plan_concept} AND person_id = #{self.id} AND voided = 0
        AND obs_datetime <= '#{date.to_date.strftime('%Y-%m-%d 23:59:59')}'
        ")

      sbp_obs.each do |obs|
        date = obs.obs_datetime.strftime('%d-%b-%Y')
        next if obs.value_numeric.blank?
        sbp_data[date] = obs.value_numeric.to_i
      end

      dbp_obs.each do |obs|
        date = obs.obs_datetime.strftime('%d-%b-%Y')
        next if obs.value_numeric.blank?
        dbp_data[date] = obs.value_numeric.to_i
      end

      plan_obs.each do |obs|
        date = obs.obs_datetime.strftime('%d-%b-%Y')
        plan_data[date] = obs.value_text
      end

      sbp_data.each do |date, sbp|
        dbp = dbp_data[date]
        plan = plan_data[date]
        plan = "" if plan.blank?
        next if dbp.blank?
        visits << {"date" => date, "systolic" => sbp, "diastolic" => dbp, "grade" => bp_grade(sbp, dbp), "plan" => plan,  "drugs" => "None"}
      end
      #visits << {"date" => record.obs_datetime.strftime('%d-%b-%Y'), "systolic" => record["SBP"],"grade" => bp_grade(record["SBP"],record["DBP"]),
      #"diastolic" => record["DBP"], "plan" => (record["plan"].blank? ? "" : record["plan"]), "drugs" => "None"}

      return visits
    end


    def bp_management_trail(date = Date.today)
=begin
      visits = []

      sbp_concept = Core::Concept.find_by_name('Systolic blood pressure').id
      dbp_concept = Core::Concept.find_by_name('Diastolic blood pressure').id
      plan_concept = Core::Concept.find_by_name('Plan').id

      records = Core::Observation.find_by_sql("SELECT  DISTINCT o.encounter_id,o.person_id,DATE(o.obs_datetime) as obs_datetime,
                                       (SELECT value_numeric FROM obs WHERE encounter_id = o.encounter_id
                                       AND concept_id = #{sbp_concept} AND person_id = o.person_id AND voided = 0 LIMIT 1) AS SBP,
                                       (SELECT value_numeric FROM obs WHERE encounter_id = o.encounter_id
                                       AND concept_id = #{dbp_concept} AND person_id = o.person_id AND voided = 0 LIMIT 1) AS DBP,
                                       (SELECT value_text FROM obs WHERE concept_id = #{plan_concept} AND person_id = o.person_id
                                       AND obs_datetime BETWEEN DATE_FORMAT(o.obs_datetime, '%Y-%m-%d 00:00:00') AND
                                       DATE_FORMAT(o.obs_datetime, '%Y-%m-%d 23:59:59') AND voided = 0 LIMIT 1) AS plan
                                       FROM obs as o WHERE o.person_id = #{self.id} AND o.voided = 0 AND obs_datetime <=
                                       '#{date.to_date.strftime('%Y-%m-%d 23:59:59')}' HAVING SBP IS NOT NULL
                                       AND DBP IS NOT NULL ORDER BY o.obs_datetime DESC, o.encounter_id DESC").each do |record|
        #visits[record.obs_datetime.strftime('%d-%b-%Y')] = [] if visits[record.obs_datetime.strftime('%d-%b-%Y')].blank?
        visits << {"date" => record.obs_datetime.strftime('%d-%b-%Y'), "systolic" => record["SBP"],"grade" => bp_grade(record["SBP"],record["DBP"]),
          "diastolic" => record["DBP"], "plan" => (record["plan"].blank? ? "" : record["plan"]), "drugs" => "None"}
      end
return visits
=end
      patient_blood_presure(date)
    end

    def current_bp_drugs(date = Date.today)
      medication_concept = Core::ConceptName.find_by_name("HYPERTENSION DRUGS").concept_id
      dispensing_concept = Core::ConceptName.find_by_name("AMOUNT DISPENSED").concept_id
      drug_concept_ids = Core::ConceptSet.all(:conditions => ['concept_set = ?', medication_concept]).map(&:concept_id)
      drugs = Core::Drug.all(:conditions => ["concept_id IN (?)", drug_concept_ids])

      prev_date = Core::Encounter.last(:select => ["encounter_datetime"], :joins => "
                INNER JOIN obs ON encounter.encounter_id = obs.encounter_id 
        ",
        :conditions => ["encounter.patient_id = ? AND encounter.voided = 0 AND value_drug IN (?) AND DATE(encounter.encounter_datetime) <=?
                               AND encounter.encounter_type = ? AND obs.value_drug  IN (?)",
          self.id, drugs.map(&:drug_id), date, Core::EncounterType.find_by_name("DISPENSING").id, drugs.map(&:drug_id)]).encounter_datetime.to_date rescue nil
                                      
      return [] if prev_date.blank?                                   
      result = Core::Encounter.find_by_sql(["SELECT obs.value_drug FROM encounter INNER JOIN obs ON obs.encounter_id = encounter.encounter_id 
      			WHERE encounter.voided = 0 AND encounter.patient_id = ? AND obs.value_drug IN (?) AND obs.concept_id = ? AND encounter.encounter_type = ? AND DATE(encounter.encounter_datetime) = ? 
          ", self.id, drugs.map(&:drug_id), dispensing_concept, Core::EncounterType.find_by_name("DISPENSING").id, prev_date]).map(&:value_drug).uniq  rescue []
      	
      
=begin
      result = DrugOrder.all(:select => ["drug_inventory_id"], :joins => "
                INNER JOIN orders ON orders.order_id = drug_order.order_id AND orders.patient_id = #{self.id}
                INNER JOIN encounter ON orders.encounter_id = encounter.encounter_id
                INNER JOIN obs ON obs.encounter_id = encounter.encounter.encounter_id
                ",
                     :conditions => ["obs.concept_id = ? drug_inventory_id IN (?) AND DATE(encounter.encounter_datetime) = ?",
                                     drugs.map(&:drug_id), prev_date]).map(&:drug_inventory_id).uniq      
=end  
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
      patient_id = self.id

      latest_date = Observation.find_by_sql("
      SELECT MAX(obs_datetime) AS date FROM obs
      WHERE person_id = #{patient_id}
        AND voided = 0
        AND concept_id IN (#{sbp_concept}, #{dbp_concept})
        AND obs_datetime <= '#{date.to_date.strftime('%Y-%m-%d 23:59:59')}'
        ").last.date.to_date rescue nil

      return nil if latest_date.blank?

      sbp = Observation.find_by_sql("
        SELECT * FROM obs
        WHERE person_id = #{patient_id}
          AND voided = 0
          AND concept_id = #{sbp_concept}
          AND obs_datetime BETWEEN '#{latest_date.to_date.strftime('%Y-%m-%d 00:00:00')}' AND '#{latest_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
        ").last.value_numeric rescue nil

      dbp = Observation.find_by_sql("
        SELECT * FROM obs
        WHERE person_id = #{patient_id}
          AND voided = 0
          AND concept_id = #{dbp_concept}
          AND obs_datetime BETWEEN '#{latest_date.to_date.strftime('%Y-%m-%d 00:00:00')}' AND '#{latest_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
        ").last.value_numeric rescue nil

      return {:patient_id => patient_id, :max_date => latest_date, :sbp => sbp, :dbp => dbp}
    end
   
    def drug_notes(date = Date.today)
      notes_concept = sbp_concept = Core::Concept.find_by_name('Notes').id
      drug_ids = ["HCZ (25mg tablet)", "Amlodipine (5mg tablet)", "Amlodipine (10mg tablet)",
        "Enalapril (5mg tablet)", "Enalapril (10mg tablet)",
        "Atenolol (50mg tablet)", "Atenolol (100mg tablet)"].collect{|name| Drug.find_by_name(name).id}
      data = Core::Observation.find_by_sql(["SELECT value_text, value_drug, obs_datetime FROM encounter INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
				WHERE encounter.encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'HYPERTENSION MANAGEMENT' LIMIT 1)
				AND encounter.patient_id = ? 
				AND DATE(encounter.encounter_datetime) <= ? 
				AND obs.concept_id = ?
				AND obs.value_drug IN (?)
				AND encounter.voided = 0
          ", self.id, date.to_date, notes_concept, drug_ids])
      result = {}
      map = {
        "HCZ (25mg tablet)" => "HCZ",
        "Amlodipine (5mg tablet)" => "Amlodipine",
        "Amlodipine (10mg tablet)" => "Amlodipine",
        "Enalapril (5mg tablet)" => "Enalapril",
        "Enalapril (10mg tablet)" => "Enalapril",
        "Atenolol (50mg tablet)" => "Atenolol",
        "Atenolol (100mg tablet)" => "Atenolol"
      }
      data.each do |obj|
        drug_name = Drug.find(obj.value_drug).name rescue nil
        name = map[drug_name]
        next if drug_name.blank? || name.blank?
		
        notes = obj.value_text
        date = obj.obs_datetime.to_date
		
        result[name] = {} if result[name].blank?
        result[name][date] = [] if result[name][date].blank?
        result[name][date] << notes
      end
      return result
    end

    def pregnancy_status(date = Date.today)
      pregnant = (Core::Observation.last(:conditions => ["person_id = ? AND voided = 0 AND concept_id = ?
                                                          AND DATE(obs_datetime) = ?",self.id,
            ConceptName.find_by_name("IS PATIENT PREGNANT?").concept_id,
            (date.to_date)
          ]).answer_string.downcase.strip rescue nil) == "yes"

      if pregnant
        return "Patient is pregnant"
      end

      answer = (Core::Observation.last(:conditions => ["person_id = ? AND voided = 0 AND concept_id = ?
                                                          AND DATE(obs_datetime) = ?",self.id,
            ConceptName.find_by_name("Why does the woman not use birth control").concept_id,
            (date.to_date)
          ]).answer_string.upcase.strip rescue nil)

      if answer == "PATIENT WANTS TO GET PREGNANT"
        return "Patient wants to get pregnant"
      elsif answer == "AT RISK OF UNPLANNED PREGNANCY"
        return "At Risk of Unplanned Pregnancy"
      end
    end

    def current_risk_factors(date = Date.today)
      encounter_type = Core::EncounterType.find_by_name("MEDICAL HISTORY").id
      concept_id = Core::ConceptName.find_by_name("HYPERTENSION RISK FACTORS").concept_id
      yes_concept_id = Core::ConceptName.find_by_name("YES").concept_id
      concept_ids = Core::ConceptSet.find_all_by_concept_set(concept_id).collect{|set| set.concept.id}
      current_risk_factors = []
      encounter_id = Core::Encounter.find_by_sql(["SELECT encounter_id FROM encounter
 					WHERE encounter.voided = 0 AND encounter.patient_id = ? AND encounter_datetime <= ?
	 					AND	encounter.encounter_type = ? ORDER BY encounter_datetime DESC,encounter_id DESC  LIMIT 1",
          self.id,date.strftime("%Y-%m-%d 23:59:59"), encounter_type]).first.id rescue nil

      if encounter_id.present?
        current_risk_factors = Core::Observation.all(:conditions => ["encounter_id = ? AND concept_id IN (?)
	 							AND (value_coded = ? OR value_text = 'YES')",
            encounter_id, concept_ids, yes_concept_id]).collect{|o| o.concept.concept_names.first.name.strip}
      end
      current_risk_factors
    end

    def were_htn_risk_factors_captured?(date)
      encounters = Core::Encounter.find(:all, :conditions => ["patient_id = ? AND encounter_datetime <= ? AND encounter_type = ?",
          self.id,date.strftime("%Y-%m%d 23:59:59"),Core::EncounterType.find_by_name("MEDICAL HISTORY").id]).collect{|x|x.id}

      return false if encounters.blank?

      risk_factors = Core::ConceptSet.find_all_by_concept_set(Core::ConceptName.find_by_name("HYPERTENSION RISK FACTORS").concept_id).collect{|set| set.concept.id}

      encounter = Core::Observation.find_by_sql(["SELECT DISTINCT encounter_id FROM obs
										WHERE encounter_id in (?) AND concept_id in (?) AND
										person_id = ? AND voided = 0 LIMIT 1",encounters, risk_factors, self.id])

      if encounter.blank?
        return false
      else
        return true
      end
    end

    def bp_grade(sbp, dbp)

      if (sbp.to_i < 140 ) && (dbp.to_i < 90)
        return "normal"
      elsif ((sbp.to_i >= 140 && sbp.to_i < 160) || (dbp.to_i >= 100 && dbp.to_i < 110))
        return "grade 1"
      elsif (sbp.to_i >= 180 && dbp.to_i > 110) || sbp.to_i >= 180
        return "grade 3"
      elsif ((sbp.to_i >= 160 && sbp.to_i < 180) || (dbp.to_i >= 110 ))
        return "grade 2"
      end
    end

    def normatensive(trail)

      dates_checked = 0
      normal_bp = 0
      dates = []
      (0..2).each do |day|
        return false if trail[day].blank?

        if trail[day]["diastolic"].to_i < 90 && trail[day]["systolic"].to_i < 140 && !dates.include?(trail[day]["date"])
          normal_bp += 1
        end
        dates_checked +=1 if !dates.include?(trail[day]["date"])
        dates << trail[day]["date"] if !dates.include?(trail[day]["date"])

        break if dates_checked == 2 && normal_bp == 2
      end

      if dates_checked == 2 && normal_bp == 2
        return true
      else
        return false
      end
    end

    def drug_use_history(date = Date.today)
      past_drugs = ""
      bp_drug_use_history = Observation.find(:last, :conditions => ["person_id =? AND
        concept_id =? AND DATE(obs_datetime) =?", self.id,
          Concept.find_by_name('DRUG USE HISTORY').id, date])

      unless bp_drug_use_history.blank?
        past_drugs = bp_drug_use_history.value_text
      end
     
      return past_drugs
    end
   
  end
end
