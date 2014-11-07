class PatientsController < ApplicationController

  before_filter :find_patient

  def show

    @links = {}

    @project = get_global_property_value("project.name") rescue "Unknown"

    render :layout => false
  end

  def blank
    render :layout => false
  end

protected

  def find_patient

    @patient = Patient.find(params[:id] || params[:patient_id]) rescue nil

  end

end
