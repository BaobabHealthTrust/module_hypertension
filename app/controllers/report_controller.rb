class ReportController < ApplicationController
  def index
  end

  def menu
   @durations, @path = ReportHelper.report_duration(params[:type])
  end

  def demographic_and_clinical
   @start_date = "#{params[:year]}/#{params[:month]}/01".to_date
   @end_date = @start_date.end_of_month
  end

  def among_those_with_hypertension
   @start_date = "#{params[:year]}/#{params[:month]}/01".to_date
   @end_date = @start_date.end_of_month
  end

  def alive_and_in_care_report
   @start_date = "#{params[:year]}/#{params[:month]}/01".to_date
   @end_date = @start_date.end_of_month
  end

  def program_evaluation_baseline

  end

  def program_evaluation_followup

  end

  def program_impact_report

  end

  def drill_down

  end

  def total_screened

   bp_concepts = Core::ConceptName.find(:all,:conditions => ["name in (?)",
                                  ['Systolic blood pressure','Diastolic blood pressure']]).collect { |x| x.concept_id }

   patients = Core::Observation.patients_with_particular_observations(bp_concepts, params[:start_date].to_date,params[:end_date].to_date)

   if params[:gender]
     patients = Core::Person.find(:all, :conditions => ["person_id in (?) AND COALESCE(gender,'unknown') in (?)",
                                                        patients,params[:gender] ]).collect{ |x| x.person_id}
   end
   render :json => patients.to_json
  end

  def total_screened_by_outcome(start_date, end_date, outcome)

  end

  def total_screen_by_place_of_diagnosis(start_date, end_date, location)

  end

  def total_screened_by_bp_classification(start_date, end_date,classification)

  end

  def total_screened_by_diagnosis(start_date, end_date, diagnosis)

  end
end
