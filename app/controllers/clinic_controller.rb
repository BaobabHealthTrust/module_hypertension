class ClinicController < ApplicationController

  before_filter :sync_user, :except => [:index, :set_datetime, :update_datetime, :reset_datetime]

  def index
    @facility = Core::Location.current_health_center.name rescue ''

    @location = Core::Location.find(session[:location_id]).name rescue ""

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

    @user = Core::User.find(session[:user_id]) rescue nil

    @roles = Core::User.find(session[:user_id]).user_roles.collect{|r| r.role} rescue []

    render :layout => false
  end

  def set_datetime
  end

  def update_datetime
    unless params[:set_day]== "" or params[:set_month]== "" or params[:set_year]== ""
      # set for 1 second after midnight to designate it as a retrospective date
      date_of_encounter = Time.mktime(params[:set_year].to_i,
                                      params[:set_month].to_i,
                                      params[:set_day].to_i,0,0,1)
      session[:datetime] = date_of_encounter #if date_of_encounter.to_date != Date.today
    end

    redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{params[:location_id]}"
  end

  def reset_datetime
    session[:datetime] = nil
    redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{params[:location_id]}" and return
  end

  def administration

    @link = "/core_user_management"

    @host = request.host_with_port rescue ""

    render :layout => false
  end

  def my_account

    @link = "/core_user_management"

    @host = request.host_with_port rescue ""

    render :layout => false
  end

  def overview
    render :layout => false
  end

  def reports
    render :layout => false
  end

  def project_users
    if !session[:user].nil?
      @user = session[:user]
    else
      @user = {"user_id" => session[:user_id]}
    end

    render :layout => false
  end

  def project_users_list
    users = Core::User.find(:all, :conditions => ["username LIKE ? AND user_id IN (?)", "#{params[:username]}%",
                                                  Core::UserProperty.find(:all, :conditions => ["property = 'Status' AND property_value = 'ACTIVE'"]
                                            ).map{|user| user.user_id}], :limit => 50)

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    result = users.collect { |user|
      [
          user.id,
          (user.user_properties.find_by_property("#{@project}.activities").property_value.split(",") rescue nil),
          (user.user_properties.find_by_property("Last Name").property_value rescue nil),
          (user.user_properties.find_by_property("First Name").property_value rescue nil),
          user.username
      ]
    }

    render :text => result.to_json
  end

  def add_to_project

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") # rescue nil

    unless params[:target].nil? || @project.nil?
      user = Core::User.find(params[:target]) rescue nil

      unless user.nil?
        Core::UserProperty.create(
            :user_id => user.id,
            :property => "#{@project}.activities",
            :property_value => ""
        )
      end
    end

    redirect_to "/project_users_list" and return
  end

  def remove_from_project

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless params[:target].nil? || @project.nil?
      user = Core::User.find(params[:target]) rescue nil

      unless user.nil?
        user.user_properties.find_by_property("#{@project}.activities").delete
      end
    end

    redirect_to "/project_users_list" and return
  end

  def manage_activities

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless @project.nil?
      @users = Core::UserProperty.find_all_by_property("#{@project}.activities").collect { |user| user.user_id }

      @roles = Core::UserRole.find(:all, :conditions => ["user_id IN (?)", @users]).collect { |role| role.role }.sort.uniq

    end

  end

  def check_role_activities
    activities = {}

    if File.exists?("#{Rails.root}/config/protocol_task_flow.yml")
      YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
      }"]["clinical.encounters.sequential.list"].split(",").each{|activity|

        activities[activity.titleize] = 0

      } rescue nil
    end

    role = params[:role].downcase.gsub(/\s/,".") rescue nil

    unless File.exists?("#{Rails.root}/config/roles")
      Dir.mkdir("#{Rails.root}/config/roles")
    end

    unless role.nil?
      if File.exists?("#{Rails.root}/config/roles/#{role}.yml")
        YAML.load_file("#{Rails.root}/config/roles/#{role}.yml")["#{Rails.env
        }"]["activities.list"].split(",").compact.each{|activity|

          activities[activity.titleize] = 1

        } rescue nil
      end
    end

    render :text => activities.to_json
  end

  def create_role_activities
    activities = []

    role = params[:role].downcase.gsub(/\s/,".") rescue nil
    activity = params[:activity] rescue nil

    unless File.exists?("#{Rails.root}/config/roles")
      Dir.mkdir("#{Rails.root}/config/roles")
    end

    unless role.nil? || activity.nil?

      file = "#{Rails.root}/config/roles/#{role}.yml"

      activities = YAML.load_file(file)["#{Rails.env
      }"]["activities.list"].split(",") rescue []

      activities << activity

      activities = activities.map{|a| a.upcase}.uniq

      f = File.open(file, "w")

      f.write("#{Rails.env}:\n    activities.list: #{activities.uniq.join(",")}")

      f.close

    end

    activities = {}

    if File.exists?("#{Rails.root}/config/protocol_task_flow.yml")
      YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
      }"]["clinical.encounters.sequential.list"].split(",").each{|activity|

        activities[activity.titleize] = 0

      } rescue nil
    end

    YAML.load_file("#{Rails.root}/config/roles/#{role}.yml")["#{Rails.env
    }"]["activities.list"].split(",").each{|activity|

      activities[activity.titleize] = 1

    } rescue nil

    render :text => activities.to_json
  end

  def remove_role_activities
    activities = []

    role = params[:role].downcase.gsub(/\s/,".") rescue nil
    activity = params[:activity] rescue nil

    unless File.exists?("#{Rails.root}/config/roles")
      Dir.mkdir("#{Rails.root}/config/roles")
    end

    unless role.nil? || activity.nil?

      file = "#{Rails.root}/config/roles/#{role}.yml"

      activities = YAML.load_file(file)["#{Rails.env
      }"]["activities.list"].split(",").map{|a| a.upcase} rescue []

      activities = activities - [activity.upcase]

      activities = activities.map{|a| a.titleize}.uniq

      f = File.open(file, "w")

      f.write("#{Rails.env}:\n    activities.list: #{activities.uniq.join(",")}")

      f.close

    end

    activities = {}

    if File.exists?("#{Rails.root}/config/protocol_task_flow.yml")
      YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
      }"]["clinical.encounters.sequential.list"].split(",").each{|activity|

        activities[activity.titleize] = 0

      } rescue nil
    end

    YAML.load_file("#{Rails.root}/config/roles/#{role}.yml")["#{Rails.env
    }"]["activities.list"].split(",").each{|activity|

      activities[activity.titleize] = 1

    } rescue nil

    render :text => activities.to_json
  end

  def project_members
  end

  def my_activities
  end

  def check_user_activities
    activities = {}

    @user[:roles].each do |role|

      role = role.downcase.gsub(/\s/,".") rescue nil

      if File.exists?("#{Rails.root}/config/roles/#{role}.yml")

        YAML.load_file("#{Rails.root}/config/roles/#{role}.yml")["#{Rails.env
        }"]["activities.list"].split(",").each{|activity|

          activities[activity.titleize] = 0 if activity.downcase.match("^" +
                                                                           (!params[:search].nil? ? params[:search].downcase : ""))

        } rescue nil

      end

    end

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless @project.nil?

      Core::UserProperty.find_by_user_id_and_property(session[:user_id],
                                                "#{@project}.activities").property_value.split(",").each{|activity|

        activities[activity.titleize] = 1 if activity.downcase.match("^" +
                                                                         (!params[:search].nil? ? params[:search].downcase : "")) and !activities[activity.titleize].nil?

      }

    end

    render :text => activities.to_json
  end

  def create_user_activity

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless @project.nil? || params[:activity].nil?

      user = Core::UserProperty.find_by_user_id_and_property(session[:user_id],
                                                       "#{@project}.activities")

      unless user.nil?
        properties = user.property_value.split(",")

        properties << params[:activity]

        properties = properties.map{|p| p.upcase}.uniq

        user.update_attribute("property_value", properties.join(","))

      else

        Core::UserProperty.create(
            :user_id => session[:user_id],
            :property => "#{@project}.activities",
            :property_value => params[:activity]
        )

      end

    end

    activities = {}

    @user[:roles].each do |role|

      role = role.downcase.gsub(/\s/,".") rescue nil

      if File.exists?("#{Rails.root}/config/roles/#{role}.yml")

        YAML.load_file("#{Rails.root}/config/roles/#{role}.yml")["#{Rails.env
        }"]["activities.list"].split(",").each{|activity|

          activities[activity.titleize] = 0 if activity.downcase.match("^" +
                                                                           (!params[:search].nil? ? params[:search].downcase : ""))

        } rescue nil

      end

    end

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless @project.nil?

      Core::UserProperty.find_by_user_id_and_property(session[:user_id],
                                                "#{@project}.activities").property_value.split(",").each{|activity|

        activities[activity.titleize] = 1

      }

    end

    render :text => activities.to_json
  end

  def remove_user_activity

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless @project.nil? || params[:activity].nil?

      user = Core::UserProperty.find_by_user_id_and_property(session[:user_id],
                                                       "#{@project}.activities")

      unless user.nil?
        properties = user.property_value.split(",").map{|p| p.upcase}.uniq

        properties = properties - [params[:activity].upcase]

        user.update_attribute("property_value", properties.join(","))
      end

    end

    activities = {}

    @user[:roles].each do |role|

      role = role.downcase.gsub(/\s/,".") rescue nil

      if File.exists?("#{Rails.root}/config/roles/#{role}.yml")

        YAML.load_file("#{Rails.root}/config/roles/#{role}.yml")["#{Rails.env
        }"]["activities.list"].split(",").each{|activity|

          activities[activity.titleize] = 0 if activity.downcase.match("^" +
                                                                           (!params[:search].nil? ? params[:search].downcase : ""))

        } rescue nil

      end

    end

    unless @project.nil?

      Core::UserProperty.find_by_user_id_and_property(session[:user_id],
                                                "#{@project}.activities").property_value.split(",").each{|activity|

        activities[activity.titleize] = 1

      }

    end

    render :text => activities.to_json
  end

  def demographics_fields
  end

  def show_selected_fields
    fields = ["Middle Name", "Maiden Name", "Home of Origin", "Current District",
              "Current T/A", "Current Village", "Landmark or Plot", "Cell Phone Number",
              "Office Phone Number", "Home Phone Number", "Occupation", "Nationality"]

    selected = YAML.load_file("#{Rails.root}/config/application.yml")["#{Rails.env
    }"]["demographic.fields"].split(",") rescue []

    @fields = {}

    fields.each{|field|
      if selected.include?(field)
        @fields[field] = 1
      else
        @fields[field] = 0
      end
    }

    render :text => @fields.to_json
  end

  def remove_field
    initial = YAML.load_file("#{Rails.root}/config/application.yml").to_hash rescue {}

    demographics = initial["#{Rails.env}"]["demographic.fields"].split(",") rescue []

    demographics = demographics - [params[:target]]

    initial["#{Rails.env}"]["demographic.fields"] = demographics.join(",")

    File.open("#{Rails.root}/config/application.yml", "w+") { |f| f.write(initial.to_yaml) }

    fields = ["Middle Name", "Maiden Name", "Home of Origin", "Current District",
              "Current T/A", "Current Village", "Landmark or Plot", "Cell Phone Number",
              "Office Phone Number", "Home Phone Number", "Occupation", "Nationality"]

    selected = YAML.load_file("#{Rails.root}/config/application.yml")["#{Rails.env
    }"]["demographic.fields"].split(",") rescue []

    @fields = {}

    fields.each{|field|
      if selected.include?(field)
        @fields[field] = 1
      else
        @fields[field] = 0
      end
    }

    render :text => @fields.to_json
  end

  def add_field
    initial = YAML.load_file("#{Rails.root}/config/application.yml").to_hash rescue {}

    demographics = initial["#{Rails.env}"]["demographic.fields"].split(",") rescue []

    demographics = demographics + [params[:target]]

    initial["#{Rails.env}"]["demographic.fields"] = demographics.join(",")

    File.open("#{Rails.root}/config/application.yml", "w+") { |f| f.write(initial.to_yaml) }

    fields = ["Middle Name", "Maiden Name", "Home of Origin", "Current District",
              "Current T/A", "Current Village", "Landmark or Plot", "Cell Phone Number",
              "Office Phone Number", "Home Phone Number", "Occupation", "Nationality"]

    selected = YAML.load_file("#{Rails.root}/config/application.yml")["#{Rails.env
    }"]["demographic.fields"].split(",") rescue []

    @fields = {}

    fields.each{|field|
      if selected.include?(field)
        @fields[field] = 1
      else
        @fields[field] = 0
      end
    }

    render :text => @fields.to_json
  end

  def lab_results
    if request.post?
      lab_results = get_global_property_value("lab_results") rescue nil
      if lab_results.nil?
        lab_results = Core::GlobalProperty.new
        lab_results.property = "lab_results"
        lab_results.property_value = params[:test_type_values].join(";")
        lab_results.save
      else
        lab_results = Core::GlobalProperty.find_by_property("lab_results")
        lab_results.property_value = params[:test_type_values].join(";")
        lab_results.save
      end
      redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}"
    end
  end

  def site_properties
=begin
    @link = get_global_property_value("user.management.url").to_s rescue nil

    if @link.nil?
      flash[:error] = "Missing configuration for <br/>user management connection!"

      redirect_to "/no_user" and return
    end
=end
    @host = request.host_with_port rescue ""

    render :layout => false
  end

  def overview
    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    @encounter_activities = Core::UserProperty.find(:first, :conditions => ["property = '#{@project}.activities' AND user_id = ?", @user[:user_id]]).property_value.split(",") rescue []
    @encounter_activities.push("APPOINTMENT")
    @to_date = Clinic.overview(@encounter_activities)
    @current_year = Clinic.overview_this_year(@encounter_activities)
    @today = Clinic.overview_today(@encounter_activities)
    @me = Clinic.overview_me(@encounter_activities, @user['user_id'])

    render :layout => false
  end

  def reports
    render :layout => false
  end

  def clinic_days
    if request.post?
      ['peads','all'].each do | age_group |
        if age_group == 'peads'
          clinic_days = Core::GlobalProperty.find_by_property('peads.clinic.days')
          weekdays = params[:peadswkdays]
        else
          clinic_days = Core::GlobalProperty.find_by_property('clinic.days')
          weekdays = params[:weekdays]
        end

        if clinic_days.blank?
          clinic_days = Core::GlobalProperty.new()
          clinic_days.property = 'clinic.days'
          clinic_days.property = 'peads.clinic.days' if age_group == 'peads'
          clinic_days.description = 'Week days when the clinic is open'
        end
        weekdays = weekdays.split(',').collect{ |wd|wd.capitalize }
        clinic_days.property_value = weekdays.join(',')
        clinic_days.save
      end
      flash[:notice] = "Week day(s) successfully created."
      redirect_to "/clinic?user_id=#{session[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}" and return
    end
    @peads_clinic_days = CoreService.get_global_property_value('peads.clinic.days') rescue nil
    @clinic_days = CoreService.get_global_property_value('clinic.days') rescue nil
    render :layout => "menu"
  end

  def prescriptions
    if request.post?
      appointment = get_global_property_value("prescription.types") rescue nil
      if appointment.nil?
        appointment= Core::GlobalProperty.new
        appointment.property = "prescription.types"
        appointment.property_value = params[:prescription]
        appointment.save
      else
        appointment = Core::GlobalProperty.find_by_property("prescription.types")
        appointment.property_value = params[:prescription]
        appointment.save
      end
      redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}"
    end
  end

  def vitals
    if request.post?
      lab_results = get_global_property_value("vitals") rescue nil
      if lab_results.nil?
        lab_results = Core::GlobalProperty.new
        lab_results.property = "vitals"
        lab_results.property_value = params[:vitals].join(";")
        lab_results.save
      else
        lab_results = Core::GlobalProperty.find_by_property("vitals")
        lab_results.property_value = params[:vitals].join(";")
        lab_results.save
      end
      redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}"
    end
  end

  def appointment
    if request.post?
      appointment = get_global_property_value("auto_set_appointment") rescue nil
      if appointment.nil?
        appointment= Core::GlobalProperty.new
        appointment.property = "auto_set_appointment"
        appointment.property_value = params[:appointment]
        appointment.save
      else
        appointment = Core::GlobalProperty.find_by_property("auto_set_appointment")
        appointment.property_value = params[:appointment]
        appointment.save
      end
      redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}"
    end
  end

  def current_center
    if request.post?
      location = Core::Location.find_by_name(params[:current_center])
      current_center = Core::GlobalProperty.find_by_property("current_health_center_name")

      if current_center.nil?
        current_center = Core::GlobalProperty.new
        current_center.property = "current_health_center_name"
        current_center.property_value = params[:current_center]
        current_center.save
      else
        current_center = Core::GlobalProperty.find_by_property("current_health_center_name")
        current_center.property_value = params[:current_center]
        current_center.save
      end

      current_id = get_global_property_value("current_health_center_id")
      if current_id.nil?
        current_id = Core::GlobalProperty.new
        current_id.property = "current_health_center_id"
        current_id.property_value = location.id
        current_id.save
      else
        current_id = Core::GlobalProperty.find_by_property("current_health_center_id")
        current_id.property_value = location.id
        current_id.save
      end
      redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}"
    end
  end

  protected

  def sync_user

    if !session[:user].nil?
      @user = session[:user]
    else
      @user = CoreUser.find(Core::User.current.id).demographics # rescue {}
    end

  end

end
