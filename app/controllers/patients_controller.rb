class PatientsController < ApplicationController
  def show
    render :layout => false
  end

  def blank
    render :layout => false
  end

end
