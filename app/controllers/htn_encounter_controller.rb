class HtnEncounterController < ApplicationController
  unloadable
  def index
  end

  def vitals

   patient = Core::Patient.find(params[:patient_id])
   @patient = patient
   @patient_eligible = patient.eligible_for_htn_screening()
   @patient_bean = PatientService.get_patient(@patient.person)
   if session[:datetime]
    @retrospective = true
   else
    @retrospective = false
   end
   #@ask_blood_pressure = patient.eligible_for_htn_diagnosis
   @current_height = PatientService.get_patient_attribute_value(@patient, "current_height")
   @min_weight = PatientService.get_patient_attribute_value(@patient, "min_weight")
   @max_weight = PatientService.get_patient_attribute_value(@patient, "max_weight")
   @min_height = PatientService.get_patient_attribute_value(@patient, "min_height")
   @max_height = PatientService.get_patient_attribute_value(@patient, "max_height")
   @user = current_user
  end

  def bp_alert
    @patient = Patient.find(params[:patient_id])
    @patient_bean = PatientService.get_patient(@patient.person)
    @bp = @patient.current_bp()
  end

  def vitals_confirmation
    @patient = Patient.find(params[:patient_id])
    @patient_bean = PatientService.get_patient(@patient.person)
    if session[:datetime]
      @retrospective = true
    else
      @retrospective = false
    end
    #@ask_blood_pressure = patient.eligible_for_htn_diagnosis
    @current_height = PatientService.get_patient_attribute_value(@patient, "current_height")
    @min_weight = PatientService.get_patient_attribute_value(@patient, "min_weight")
    @max_weight = PatientService.get_patient_attribute_value(@patient, "max_weight")
    @min_height = PatientService.get_patient_attribute_value(@patient, "min_height")
    @max_height = PatientService.get_patient_attribute_value(@patient, "max_height")
  end

  def family_history
   patient = Patient.find(params[:patient_id])
   @patient = patient
  end

  def social_history
   @patient = Patient.find(params[:patient_id])
  end

  def general_health
   @patient = Patient.find(params[:patient_id])

   if @patient.get_general_health(session[:datetime])
    @existing_conditions = ["Heart disease", "Stroke", "TIA", "Diabetes", "Kidney Disease"]
    @drugs = MedicationService.hypertension_dm_drugs.collect { |x| x.concept.fullname}
    @drugs = @drugs.sort.uniq
   else
    redirect_to next_task(@patient)
   end
  end

  def lab_results
  end

  def complications
  end

  def bp_triage
  end

  def update_outcome
  end

 def create

  encounter = Encounter.new()
  encounter.encounter_type = EncounterType.find_by_name(params["encounter"]["encounter_type_name"]).id
  encounter.patient_id = params['encounter']['patient_id']
  encounter.encounter_datetime = params['encounter']['encounter_datetime']

  if params[:filter] and !params[:filter][:provider].blank?
   user_person_id = User.find_by_username(params[:filter][:provider]).person_id

  else
   user_person_id = User.find_by_user_id(params['encounter']['provider_id']).person_id

  end
  encounter.provider_id = user_person_id
  encounter.save
  create_obs(encounter, params)

  if encounter.name == "VITALS" && encounter.observations.length == 2
    bp  = encounter.patient.current_bp
    if !bp.blank? && ((!bp[0].blank? && bp[0] > 140) || (!bp[1].blank?  && bp[1] > 90))
      redirect_to "/htn_encounter/bp_management?patient_id=#{encounter.patient_id}" and return
    end
  end
  redirect_to next_task(Patient.find(params['encounter']['patient_id']))
 end

  def create_obs(encounter , params)
   # Observation handling
   # Chunk of code re-used from ccc
   (params[:observations] || []).each do |observation|
    next if observation[:concept_name] == ""
    # Check to see if any values are part of this observation
    # This keeps us from saving empty observations
    values = ['coded_or_text', 'coded_or_text_multiple', 'group_id', 'boolean', 'coded', 'drug', 'datetime', 'numeric', 'modifier', 'text'].map { |value_name|
     observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
    }.compact

    next if values.length == 0

    observation[:value_text] = observation[:value_text].join(", ") if observation[:value_text].present? && observation[:value_text].is_a?(Array)
    observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
    observation[:encounter_id] = encounter.id
    observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
    observation[:person_id] ||= encounter.patient_id
    observation[:concept_name].upcase ||= "DIAGNOSIS" if encounter.type.name.upcase == "OUTPATIENT DIAGNOSIS"

    # Handle multiple select

    if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(String)
     observation[:value_coded_or_text_multiple] = observation[:value_coded_or_text_multiple].split(';')
    end

    if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array)
     observation[:value_coded_or_text_multiple].compact!
     observation[:value_coded_or_text_multiple].reject!{|value| value.blank?}
    end

    # convert values from 'mmol/litre' to 'mg/declitre'
    if(observation[:measurement_unit])
     observation[:value_numeric] = observation[:value_numeric].to_f * 18 if ( observation[:measurement_unit] == "mmol/l")
     observation.delete(:measurement_unit)
    end

    if(!observation[:parent_concept_name].blank?)
     concept_id = Concept.find_by_name(observation[:parent_concept_name]).id rescue nil
     observation[:obs_group_id] = Observation.find(:last, :conditions=> ['concept_id = ? AND encounter_id = ?', concept_id, encounter.id], :order => "obs_id ASC, date_created ASC").id rescue ""
     observation.delete(:parent_concept_name)
    else
     observation.delete(:parent_concept_name)
     observation.delete(:obs_group_id)
    end

    extracted_value_numerics = observation[:value_numeric]
    extracted_value_coded_or_text = observation[:value_coded_or_text]

    #TODO : Added this block with Yam, but it needs some testing.
    if params[:location]
     if encounter.encounter_type == EncounterType.find_by_name("ART ADHERENCE").id
      passed_concept_id = Concept.find_by_name(observation[:concept_name]).concept_id rescue -1
      obs_concept_id = Concept.find_by_name("AMOUNT OF DRUG BROUGHT TO CLINIC").concept_id rescue -1
      if observation[:order_id].blank? && passed_concept_id == obs_concept_id
       order_id = Order.find(:first,
                             :select => "orders.order_id",
                             :joins => "INNER JOIN drug_order USING (order_id)",
                             :conditions => ["orders.patient_id = ? AND drug_order.drug_inventory_id = ?
										  AND orders.start_date < ?", encounter.patient_id,
                                             observation[:value_drug], encounter.encounter_datetime.to_date],
                             :order => "orders.start_date DESC").order_id rescue nil
       if !order_id.blank?
        observation[:order_id] = order_id
       end
      end
     end
    end

    if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array) && !observation[:value_coded_or_text_multiple].blank?
     values = observation.delete(:value_coded_or_text_multiple)
     values.each do |value|
      observation[:value_coded_or_text] = value
      if observation[:concept_name].humanize == "Tests ordered"
       observation[:accession_number] = Observation.new_accession_number
      end

      observation = update_observation_value(observation)

      Observation.create(observation)
     end
    elsif extracted_value_numerics.class == Array
     extracted_value_numerics.each do |value_numeric|
      observation[:value_numeric] = value_numeric

      if !observation[:value_numeric].blank? && !(Float(observation[:value_numeric]) rescue false)
       observation[:value_text] = observation[:value_numeric]
       observation.delete(:value_numeric)
      end

      Observation.create(observation)
     end
    else
     observation.delete(:value_coded_or_text_multiple)
     observation = update_observation_value(observation) if !observation[:value_coded_or_text].blank?

     if !observation[:value_numeric].blank? && !(Float(observation[:value_numeric]) rescue false)
      observation[:value_text] = observation[:value_numeric]
      observation.delete(:value_numeric)
     end

     Observation.create(observation)
    end
   end
  end

  def update_observation_value(observation)
   # Chunk of code re-used from ccc
   value = observation[:value_coded_or_text]
   value_coded_name = ConceptName.find_by_name(value)

   if value_coded_name.blank?
    observation[:value_text] = value
   else
    observation[:value_coded_name_id] = value_coded_name.concept_name_id
    observation[:value_coded] = value_coded_name.concept_id
   end
   observation.delete(:value_coded_or_text)
   return observation
  end

 def assessment

  @patient = Patient.find(params[:patient_id]) rescue nil

  @diabetic = ConceptName.find_by_concept_id(PatientService.get_patient_attribute_value(@patient, "Patient has Diabetes")).name rescue ""

  @status = Observation.find_by_sql("SELECT * from obs
          WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'current smoker' LIMIT 1)
          AND voided = 0
          AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_coded rescue "No"

  #raise @status.to_yaml
  @smoking_status = ConceptName.find_by_concept_id(@status).name rescue "No"

  @systolic_value = Observation.find_by_sql("SELECT * from obs
          WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'systolic blood pressure' LIMIT 1)
          AND voided = 0
          AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0

  cholesterol_value = Observation.find_by_sql("SELECT * from obs
          WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'cholesterol test type' LIMIT 1)
          AND voided = 0
          AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.obs_id rescue nil

  @cholesterol_value = Observation.find(:all, :conditions => ['obs_group_id = ?', cholesterol_value]).first.value_numeric.to_i rescue 0

  @first_visit = false #is_first_hypertension_clinic_visit(@patient.id)

 end

 def bp_management
  @patient = Core::Patient.find(params[:patient_id])
 end

 def bp_drug_management
  @patient = Core::Patient.find(params[:patient_id])
 end
end
