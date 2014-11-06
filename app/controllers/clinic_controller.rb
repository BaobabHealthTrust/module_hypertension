class ClinicController < ApplicationController

  def index
    @facility = Location.current_health_center.name rescue ''

    @location = Location.find(session[:location_id]).name rescue ""

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

    @user = User.find(session[:user_id]) rescue nil

    @roles = User.find(session[:user_id]).user_roles.collect{|r| r.role} rescue []

    render :layout => 'menu'
  end

end
