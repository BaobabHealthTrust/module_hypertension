class ReportController < ApplicationController
  def index
  end

  def menu
   @durations, @path = ReportHelper.report_duration(params[:type])
  end

  def demographic_and_clinical

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

end
