class PatientsController < ApplicationController

  before_filter :find_patient

  def show
    # raise session.to_yaml

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
