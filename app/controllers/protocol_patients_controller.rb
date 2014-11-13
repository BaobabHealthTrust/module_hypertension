
class ProtocolPatientsController < ApplicationController

	def update_hiv_status

    @patient = Core::Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = Core::User.find(params[:user_id]) rescue nil?

    redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def asthma_measure
    @condition = []
    @familyhistory = []
    expected = ""
    predicted = ""
    current_date = (!session[:datetime].nil? ? session[:datetime].to_date : Date.today)
    @patient = Core::Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = Core::User.find(params[:user_id]) rescue nil?

    redirect_to '/encounters/no_patient' and return if @user.nil?

    observation = Core::Observation.find(:all,
      :conditions => ["encounter_id = ?", Core::Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
            current_date, @patient.id,Core::EncounterType.find_by_name("Vitals").id]).encounter_id]) rescue []
    #raise observation.to_s.to_yaml
    observation.each {|obs|
      value = Core::ConceptName.find_by_concept_id(obs.value_coded).name if !obs.value_coded.blank?
      value = obs.value_numeric.to_i if !obs.value_numeric.blank?
      value = obs.value_text if !obs.value_text.blank?
      value = obs.value_datetime if !obs.value_datetime.blank?
      if obs.concept.fullname == "PEAK FLOW PREDICTED"
        value = value.to_i
        predicted = value
      end
      expected = value.to_i if obs.concept.fullname.upcase == "PEAK FLOW"

      asthma_values = ["PEAK FLOW PREDICTED","PEAK FLOW", "BODY MASS INDEX, MEASURED","RESPIRATORY RATE", "CARDIOVASCULAR SYSTEM DIAGNOSIS"]
      next if !asthma_values.include?(obs.concept.fullname.upcase)
      @condition.push("#{obs.concept.fullname.humanize} : #{value}")
    }
    @sthmatic = ""
    if expected < predicted
      @sthmatic = "yes"
      @condition.push('<i style="color: #B8002E">Expiratory measurement below normal : Possibly indicate obstructed airways</i>')
    end
    observation = Core::Observation.find(:all,
      :conditions => ["encounter_id = ?", Core::Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
            current_date, @patient.id,Core::EncounterType.find_by_name("FAMILY MEDICAL HISTORY").id]).encounter_id]) rescue []
	
    @estimatedvalue = []
    @familyvalue = 0
    observation.each {|obs|
      value = Core::ConceptName.find_by_concept_id(obs.value_coded).name if !obs.value_coded.blank?
      value = obs.value_numeric.to_i if !obs.value_numeric.blank?
      value = obs.value_text if !obs.value_text.blank?
      value = obs.value_datetime if !obs.value_datetime.blank? 
      asthma_values = ["HYPERTENSION", "ASTHMA"]
      if asthma_values.include?(obs.concept.fullname.upcase)
        @familyvalue = value.to_i if obs.concept.fullname.to_s.upcase == "ASTHMA"
        @estimatedvalue.push("#{obs.concept.fullname.humanize}" + ' in percentage : <i style="color: #B8002E">' + "#{value.to_i}" + '</i>')
        next
      end
      @familyhistory.push("#{obs.concept.fullname.humanize} : #{value}")
    }
    @familyhistory +=  @estimatedvalue
	end

	def medical_history

    @patient = Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @current_program = current_program
       program_id = Core::Program.find_by_name('CHRONIC CARE PROGRAM').id
    date = Date.today
         @current_state = Core::PatientState.find_by_sql("SELECT p.patient_id, current_state_for_program(p.patient_id, #{program_id}, '#{date}') AS state, c.name as status FROM patient p
                      INNER JOIN  patient_program pp on pp.patient_id = p.patient_id
                      inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                      INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{program_id}, '#{date}')
                      INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                      WHERE p.patient_id = #{@patient.id}").first.status rescue ""
    
    @user = Core::User.find(params[:user_id]) rescue nil?
    @regimen_concepts = MedicationService.hypertension_dm_drugs

    redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def treatment
    @current_program = current_program
    @patient = Core::Patient.find(params[:patient_id]) rescue nil
    current_date = (!session[:datetime].nil? ? session[:datetime].to_date : Date.today)
    previous_days = 3.months
    current_date = current_date - previous_days
    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = Core::User.find(params[:user_id]) rescue nil?

    redirect_to '/encounters/no_patient' and return if @user.nil?
    if current_program == "EPILEPSY PROGRAM"
      @number = Core::Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Number of seizure including current' LIMIT 1)
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.to_s.split(":")[1].squish.to_i rescue ""

      @patient_epileptic = Core::Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Confirm diagnosis of epilepsy' LIMIT 1)
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.to_s.split(":")[1].squish.upcase rescue "NO"

      render :template => "/protocol_patients/epilepsy_diagnosis"
    end

    @age = @patient.age
    @sbp = Core::Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'SBP' LIMIT 1)
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0

    @previous_sbp = Core::Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'SBP' LIMIT 1)
                   AND DATE(obs_datetime) <= #{current_date}
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0

    @previous_dbp = Core::Observation.find_by_sql("SELECT * from obs
               WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'DBP' LIMIT 1)
               AND DATE(obs_datetime) <= #{current_date}
               AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0


    @dbp = Core::Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'DBP' LIMIT 1)
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0

    @bmi = Core::Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'bmi' LIMIT 1)
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.to_s.split(":")[1].squish.to_f.round(2) rescue 0

    @smoking = Vitals.current_vitals(@patient, "current smoker").to_s.split(":")[1].squish.upcase rescue "Unknown"
    @drinking = Vitals.current_vitals(@patient, "Does the patient drink alcohol?").to_s.split(":")[1].squish.upcase rescue "Unknown"

    current_date = current_date + 2.months
    
    @previous_treatment = check_encounter(@patient, "TREATMENT", current_date)

    @bp = (@sbp / @dbp).to_f rescue 0
    @previous_bp = (@previous_sbp / @previous_dbp).to_f rescue 0
    @normal_bp = (180/100)

    @category = "Mild"

    if ! @sbp.blank? and ! @dbp.blank?
          if (@sbp >= 140 and @sbp < 160) and (@dbp >= 100 and @dbp < 110)
            @category = "Mild"
          elsif (@sbp >= 160 and @sbp < 180) and (@dbp >= 90 and @dbp < 100)
            @category = "Moderate"
          elsif (@sbp >= 180) and (@dbp >= 110)
            @category = "Severe"
          end
    end
    #@sbp = Vitals.current_vitals(@patient, "SYSTOLIC BLOOD PLEASURE")
    #raise @category.to_yaml
	end

	def lab_results

    @patient = Core::Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = Core::User.find(params[:user_id]) rescue nil?

    redirect_to '/encounters/no_patient' and return if @user.nil?
    treatments_list = get_global_property_value("lab_results").split(";") rescue ""
    if current_program == "EPILEPSY PROGRAM"
      @sugar = ["FASTING BLOOD SUGAR", "RANDOM BLOOD SUGAR"]
    else
      @cholesterol = ["FASTING BLOOD SUGAR", "RANDOM BLOOD SUGAR", "CREATININE", "HbA1c"]

      @sugar = ["CHOLESTEROL FASTING", "CHOLESTEROL NOT FASTING", "CREATININE"]
      if treatments_list.blank?
        flash[:notice] = "No lab orders specified to collect!"
        redirect_to "/patients/show/#{@patient.id}?user_id=#{params[:user_id]}" and return
      end

      @cholesterol = (treatments_list - @cholesterol rescue [])

      @sugar = treatments_list - @sugar  rescue []

      @generic = treatments_list - (@sugar + @cholesterol)  rescue []
    end

    @current_program = current_program

	end

	def vitals
    current_date = (!session[:datetime].nil? ? session[:datetime].to_date : Date.today)
    @patient = Core::Patient.find(params[:patient_id]) #rescue nil
    
    redirect_to '/encounters/no_patient' and return if @patient.blank?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = Core::User.find(params[:user_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @user.nil?

    concept = Core::ConceptName.find_by_sql("select concept_id from concept_name where name = 'height (cm)' and voided = 0").first.concept_id


    @current_hieght  = Core::Observation.find_by_sql("SELECT * from obs where concept_id = '#{concept}' AND person_id = '#{@patient.id}'
                    AND DATE(obs_datetime) <= '#{current_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first.to_s.split(':')[1].squish rescue 0
    #raise @current_hieght.to_s.split(':')[1].squish.to_yaml

   @current_hieght = @current_hieght.value_numeric.to_i rescue @current_hieght.value_text.to_i rescue nil
    @treatements_list = get_global_property_value("vitals").split(";") rescue ""
  
	end

	def update_outcome

    @patient = Core::Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = Core::User.find(params[:user_id]) rescue nil?

    redirect_to '/encounters/no_patient' and return if @user.nil?


	end

	def outcomes

    @patient = Core::Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = Core::User.find(params[:user_id]) rescue nil?

    redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def general_health

    @patient = Core::Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end
       program_id = Core::Program.find_by_name('CHRONIC CARE PROGRAM').id
    date = Date.today
         @current_state = Core::PatientState.find_by_sql("SELECT p.patient_id, current_state_for_program(p.patient_id, #{program_id}, '#{date}') AS state, c.name as status FROM patient p
                      INNER JOIN  patient_program pp on pp.patient_id = p.patient_id
                      inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                      INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{program_id}, '#{date}')
                      INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                      WHERE p.patient_id = #{@patient.id}").first.status rescue ""

    @user = Core::User.find(params[:user_id]) rescue nil?

    redirect_to '/encounters/no_patient' and return if @user.nil?

    @regimen_concepts = MedicationService.hypertension_dm_drugs

    @circumference = Core::Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'waist circumference' LIMIT 1) AND voided = 0
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0
    @diabetic = Core::ConceptName.find_by_concept_id(Vitals.get_patient_attribute_value(@patient, "Patient has Diabetes")).name rescue "unknown"


    @bmi = Core::Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Body mass index, measured' LIMIT 1) AND voided = 0
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1")
    @bmi = @bmi.first.value_text.to_i rescue @bmi.first.value_numeric rescue 0

    @treatements_list = ["Heart disease", "Stroke", "TIA", "Diabetes", "Kidney Disease", "Head Injury", "Unknown"]

      @treatements_list.delete_if {|var| var == "Diabetes"} if @diabetic.upcase == "YES"  #Already diagnosed
    @current_program = current_program
    if current_program == "HYPERTENSION PROGRAM"
       @treatements_list.delete_if {|var| var == "Head Injury"} #Not useful for diabetes
      if @bmi < 25 and @circumference < 90
        @task = "disable" 
      end
    end
	end

	def complications

    @patient = Core::Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = Core::User.find(params[:user_id]) rescue nil?
     @treatements_list = ["Amputation", "Stroke", "Myocardial injactia(MI)", "Creatinine", "Funduscopy","Shortness of breath","Oedema","CVA", "Peripheral nueropathy", "Foot ulcers", "Visual Blindness", "Impotence", "Others"]

    redirect_to '/encounters/no_patient' and return if @user.nil?
    current_date = (!session[:datetime].nil? ? session[:datetime].to_date : Date.today)
	  enc = check_encounter(@patient, "lab results", current_date ).to_s
    
    @treatements_list.delete_if {|var| var == "Oedema"} if ! enc.match(/Blood Sugar Test Type:  Fasting/)
    @treatements_list.delete_if {|var| var == "Shortness of breath"} if ! enc.match(/Blood Sugar Test Type:  Random/)
    @treatements_list.delete_if {|var| var == "Funduscopy"} if ! enc.match(/Cholesterol Test Type:  Fasting/)
    @treatements_list.delete_if {|var| var == "Creatinine"} if ! enc.match(/Cholesterol Test Type:  Not Fasting/)
	end

	def assessment

    @patient = Core::Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = Core::User.find(params[:user_id]) rescue nil?

    redirect_to '/encounters/no_patient' and return if @user.nil?

    @diabetic = Core::ConceptName.find_by_concept_id(Vitals.get_patient_attribute_value(@patient, "Patient has Diabetes")).name rescue ""

    @status = Core::Observation.find_by_sql("SELECT * from obs
          WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'current smoker' LIMIT 1)
          AND voided = 0
          AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_coded rescue "No"

	 #raise @status.to_yaml
    @smoking_status = Core::ConceptName.find_by_concept_id(@status).name rescue "No"

    @systolic_value = Core::Observation.find_by_sql("SELECT * from obs
          WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'systolic blood pressure' LIMIT 1)
          AND voided = 0
          AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0

    cholesterol_value = Core::Observation.find_by_sql("SELECT * from obs
          WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'cholesterol test type' LIMIT 1)
          AND voided = 0
          AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.obs_id rescue nil

    @cholesterol_value = Core::Observation.find(:all, :conditions => ['obs_group_id = ?', cholesterol_value]).first.value_numeric.to_i rescue 0

    @first_vist = is_first_hypertension_clinic_visit(@patient.id)
    
	end

	def clinic_visit

    current_date = (!session[:datetime].nil? ? session[:datetime].to_date : Date.today)
    @patient = Core::Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = Core::User.find(params[:user_id]) rescue nil?

    redirect_to '/encounters/no_patient' and return if @user.nil?

    @diabetic = Vitals.current_encounter(@patient, "assessment", "Patient has Diabetes") rescue []
	
    @current_program = current_program
    #@occupation = Vitals.occupation(@patient)
     program_id = Core::Program.find_by_name('CHRONIC CARE PROGRAM').id
    date = Date.today
         @current_state = Core::PatientState.find_by_sql("SELECT p.patient_id, current_state_for_program(p.patient_id, #{program_id}, '#{date}') AS state, c.name as status FROM patient p
                      INNER JOIN  patient_program pp on pp.patient_id = p.patient_id
                      inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                      INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{program_id}, '#{date}')
                      INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                      WHERE p.patient_id = #{@patient.id}").first.status rescue ""

		if @current_program == "EPILEPSY PROGRAM"
      @regimen_concepts = MedicationService.epilepsy_drugs
      @first_visit = is_first_epilepsy_clinic_visit(@patient.id)
      @mrdt = Vitals.current_vitals(@patient, "RDT or blood smear positive for malaria") rescue []
      unless @mrdt.blank?
        @mrdt = @mrdt.value_text.upcase rescue Core::ConceptName.find_by_concept_id(@mrdt.value_coded).name.upcase
      end
       concept = Core::ConceptName.find_by_name('Patient in active seizure').concept_id
      @in_seizure  = Core::Observation.find_by_sql("SELECT * from obs where concept_id = '#{concept}' AND person_id = '#{@patient.id}'
                    AND DATE(obs_datetime) = '#{current_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first.to_s.upcase.split(":")[1].squish rescue []
      render :template => "/protocol_patients/epilepsy_clinic_visit" and return
		end
		@first_visit = is_first_hypertension_clinic_visit(@patient.id) unless current_program == "EPILEPSY PROGRAM"
	end

	def family_history
    @patient = Core::Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
			redirect_to '/encounters/no_user' and return
    end
      program_id = Core::Program.find_by_name('CHRONIC CARE PROGRAM').id
    date = Date.today
         @current_state = Core::PatientState.find_by_sql("SELECT p.patient_id, current_state_for_program(p.patient_id, #{program_id}, '#{date}') AS state, c.name as status FROM patient p
                      INNER JOIN  patient_program pp on pp.patient_id = p.patient_id
                      inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                      INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{program_id}, '#{date}')
                      INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                      WHERE p.patient_id = #{@patient.id}").first.status rescue ""

    @user = Core::User.find(params[:user_id]) rescue nil?
			
    redirect_to '/encounters/no_patient' and return if @user.nil?

    @diabetic = Vitals.current_encounter(@patient, "assessment", "Patient has Diabetes") rescue []

    @first_visit = is_first_hypertension_clinic_visit(@patient.id)
    
    @current_program = current_program

	end

	def social_history
    @patient = Core::Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
			redirect_to '/encounters/no_user' and return
    end

    @user = Core::User.find(params[:user_id]) rescue nil?

    redirect_to '/encounters/no_patient' and return if @user.nil?

    @diabetic = Vitals.current_encounter(@patient, "assessment", "Patient has Diabetes") rescue []

    @first_visit = is_first_hypertension_clinic_visit(@patient.id)
		 occupation_attribute = Core::PersonAttributeType.find_by_name("Occupation")
     @person_attribute = Core::PersonAttribute.find(:first, :conditions => ["person_id = ? AND person_attribute_type_id = ?", @patient.person.id, occupation_attribute.person_attribute_type_id]).value rescue "Unknown"
     @person_attribute = "<span>   :Patient occupation is " + @person_attribute + "</span>"
    @current_program = current_program
	end

  
end
