class PatientsController < ApplicationController

  before_filter :find_patient

  def show

    @links = {}

    @task.tasks.each{|task|

      next if task.downcase == "update baby outcome" and (@patient.current_babies.length == 0 rescue false)
      next if !@task.current_user_activities.include?(task)

      ctrller = "protocol_patients"

      if File.exists?("#{Rails.root}/config/protocol_task_flow.yml")

        ctrller = YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{task.downcase.gsub(/\s/, "_")}"] rescue ""

      end

      @links[task.titleize] = "/#{ctrller}/#{task.gsub(/\s/, "_")}?patient_id=#{
      @patient.id}&user_id=#{params[:user_id]}" + (task.downcase == "update baby outcome" ?
          "&baby=1&baby_total=#{(@patient.current_babies.length rescue 0)}" : "")

    }

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
