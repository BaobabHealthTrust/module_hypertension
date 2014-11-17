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

  end

  def alive_and_in_care_report

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
     render :json => [8,8,9,3,1,8,2,3].to_json and return
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
