class PatientsController < ApplicationController

  before_filter :find_patient

  def show
    @patient = Patient.find(params[:id] || params[:patient_id]) rescue nil

    @retrospective = session[:datetime]
    @retrospective = Time.now if session[:datetime].blank?

    @user = User.current rescue nil

    session[:patient_id] = @patient.id
    session[:user_id] = @user.id
    session[:location_id] = params[:location_id]

    program_id = Program.find_by_name('CHRONIC CARE PROGRAM').id
    date = Date.today
    @current_state = PatientState.find_by_sql("SELECT p.patient_id, current_state_for_program(p.patient_id, #{program_id}, '#{date}') AS state, c.name as status FROM patient p
                      INNER JOIN  patient_program pp on pp.patient_id = p.patient_id
                      inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                      INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{program_id}, '#{date}')
                      INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                      WHERE DATE(ps.start_date) <= '#{date}'
                      AND p.patient_id = #{@patient.id}").first.status rescue ""


    @links = {}

    @project = get_global_property_value("project.name") rescue "Unknown"

    # render :layout => false
  end

  def blank
    render :layout => false
  end


  def baby_chart

   @patient = Patient.find(params[:patient_id])
   @baby = @patient

   if (@baby.person.gender.downcase.match(/f/i))
    file =  File.open(RAILS_ROOT + "/public/data/weight_for_age_girls.txt", "r")
   else
    file =  File.open(RAILS_ROOT + "/public/data/weight_for_age_boys.txt", "r")
   end
   @file = []

   file.each{ |parameters|

    line = parameters
    line = line.split(" ").join(",")
    @file << line

   }

   #get available weights

   @weights = []
   birthdate_sec = @patient.person.birthdate

   ids = ConceptName.find(:all, :conditions => ["name IN (?)", ["WEIGHT", "BIRTH WEIGHT", "BIRTH WEIGHT AT ADMISSION", "WEIGHT (KG)"]]).collect{|concept|
    concept.concept_id}

   Observation.find(:all, :conditions => ["person_id = ? AND concept_id IN (?)",
                                          @patient.id, ids]).each do |ob|
    age = ((((ob.value_datetime.to_date rescue ob.obs_datetime.to_date) rescue ob.date_created.to_date) - birthdate_sec).days.to_i/(60*60*24)).to_s rescue nil
    weight = ob.answer_string.to_i rescue nil
    next if age.blank? || weight.blank?
    weight = (weight > 100) ? weight/1000.0 : weight # quick check of weight in grams and that in KG's
    @weights << age + "," + weight.to_s if !age.blank? && !weight.blank?

   end

   if !params[:cur_weight].blank?
    wt = params[:cur_weight].to_f
    weight = (wt > 100) ? wt/1000.0 : wt
    age = (((session[:datetime].to_date rescue Date.today) - birthdate_sec).days.to_i/(60*60*24)).to_s rescue nil
    @weights << age + "," + weight.to_s if !age.blank? && !weight.blank?
   end


   render :template => "/patients/baby_chart", :layout => false

  end


  def graphs
   @currentWeight = params[:currentWeight]
   @patient = Patient.find(params[:id])
   concept_id = ConceptName.find_by_name("Weight (Kg)").concept_id
   session_date = (session[:datetime].to_date rescue Date.today).strftime('%Y-%m-%d 23:59:59')
   obs = []

   Observation.find_by_sql("
          SELECT * FROM obs WHERE person_id = #{@patient.id}
          AND concept_id = #{concept_id} AND voided = 0 AND obs_datetime <= '#{session_date}' LIMIT 10").each {|weight|
    obs <<  [weight.obs_datetime.to_date, weight.to_s.split(':')[1].squish.to_f]
   }

   obs << [session_date.to_date, @currentWeight.to_f]
   @obs = obs.sort_by{|atr| atr[0]}.to_json


   render :template => "patients/weight_chart", :layout => false

   end
protected

  def find_patient

    @patient = Patient.find(params[:id] || params[:patient_id]) rescue nil


  end

end
