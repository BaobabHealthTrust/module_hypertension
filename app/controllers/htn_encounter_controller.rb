class HtnEncounterController < ApplicationController
  def index
  end

  def vitals
   patient = Patient.first
   @patient = patient
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
  end

  def social_history
   patient = Patient.first
   @patient = patient

  end

  def general_health
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

 raise params.inspect
 if params["encounter"]["encounter_type_name"] == "VITALS"
  encounter = Encounter.new()
  encounter.encounter_type = EncounterType.find_by_name("VITALS").id
  encounter.patient_id = params['encounter']['patient_id']
  encounter.encounter_datetime = params['encounter']['encounter_datetime']

  if params[:filter] and !params[:filter][:provider].blank?
   user_person_id = User.find_by_username(params[:filter][:provider]).person_id
  else
   user_person_id = User.find_by_user_id(params['encounter']['provider_id']).person_id
  end
  encounter.provider_id = user_person_id
  encounter.save
  create_obs(encounter, params["observations"])
 end
 end

 def create_obs(encounter, observations)

  (observations || []).each do |observation|
   values = ['coded_or_text', 'coded_or_text_multiple', 'group_id', 'boolean', 'coded', 'drug', 'datetime', 'numeric', 'modifier', 'text'].map { |value_name|
    "value_#{value_name}" unless observation["value_#{value_name}"].blank? rescue nil
   }.compact

   next if values.length == 0

   (observation.keys - values || []).each do |empty_key|
    observation.delete(empty_key)
   end


   observation[:encounter_id] = encounter.id
   observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
   observation[:person_id] ||= encounter.patient_id

   Observation.create(observation)
  end
 end
end
