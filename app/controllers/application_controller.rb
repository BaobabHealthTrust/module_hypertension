# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  unloadable
  Core::User
  Core::Location

  helper :all # include all helpers, all the time
  # protect_from_forgery # See ActionController::RequestForgeryProtection for details



  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password
=begin
  before_filter :authenticate_user!, :except => ['login', 'logout','remote_demographics',
                                                 'create_remote', 'mastercard_printable', 'get_token',
                                                 'cohort','demographics_remote', 'export_on_art_patients', 'art_summary',
                                                 'art_summary_dispensation', 'print_rules', 'rule_variables', 'print','new_prescription',
                                                 'search_for_drugs','mastercard_printable'
  ]
=end

  before_filter :authenticate_user, :except => ['login', 'logout','remote_demographics',
                                                 'create_remote', 'mastercard_printable', 'get_token',
                                                 'cohort','demographics_remote', 'export_on_art_patients', 'art_summary',
                                                 'art_summary_dispensation', 'print_rules', 'rule_variables', 'print','new_prescription',
                                                 'search_for_drugs','mastercard_printable', 'authenticate', 'verify']

  before_filter :set_current_user, :except => ['login', 'logout','remote_demographics',
                                               'create_remote', 'mastercard_printable', 'get_token',
                                               'cohort','demographics_remote', 'export_on_art_patients', 'art_summary',
                                               'art_summary_dispensation', 'print_rules', 'rule_variables', 'print','new_prescription',
                                               'search_for_drugs','mastercard_printable', 'authenticate', 'verify', 'location_update'
  ]

  before_filter :location_required, :except => ['login', 'logout', 'location',
                                                'demographics','create_remote',
                                                'mastercard_printable',
                                                'remote_demographics', 'get_token',
                                                'cohort','demographics_remote', 'export_on_art_patients', 'art_summary',
                                                'art_summary_dispensation', 'print_rules', 'rule_variables', 'print','new_prescription',
                                                'search_for_drugs','mastercard_prin`table', 'authenticate', 'verify', 'location_update'
  ]

  before_filter :set_return_uri

  def get_global_property_value(global_property)
    property_value = Settings[global_property]
    if property_value.nil?
      property_value = Core::GlobalProperty.find(:first, :conditions => {:property => "#{global_property}"}
      ).property_value rescue nil
    end
    return property_value
  end

  def generic_locations
    field_name = "name"

    Core::Location.find_by_sql("SELECT *
          FROM location
          WHERE location_id IN (SELECT location_id
                         FROM location_tag_map
                          WHERE location_tag_id = (SELECT location_tag_id
                                 FROM location_tag
                                 WHERE name = 'Workstation Location' LIMIT 1))
             ORDER BY name ASC").collect{|name| name.send(field_name)} rescue []
  end

  def use_user_selected_activities
    CoreService.get_global_property_value('use.user.selected.activities').to_s == "true" rescue false
  end

  def current_user_roles
    user_roles = Core::UserRole.find(:all,:conditions =>["user_id = ?", current_user.id]).collect{|r|r.role}
    Core::RoleRole.find(:all,:conditions => ["child_role IN (?)", user_roles]).collect{|r|user_roles << r.parent_role}
    return user_roles.uniq
  end

  def current_program_location
    current_user_activities = current_user.activities
    if Core::Location.current_location.name.downcase == 'outpatient'
      return "OPD"
    elsif current_user_activities.include?('Manage Lab Orders') or current_user_activities.include?('Manage Lab Results') or
        current_user_activities.include?('Manage Sputum Submissions') or current_user_activities.include?('Manage TB Clinic Visits') or
        current_user_activities.include?('Manage TB Reception Visits') or current_user_activities.include?('Manage TB Registration Visits') or
        current_user_activities.include?('Manage HIV Status Visits')
      return 'TB program'
    else #if current_user_activities
      return 'HIV program'
    end
  end

  def location_required

    location = session[:sso_location] rescue nil

    if location.nil?
      redirect_to "/core_user_management/location?user_id=#{session[:user_id]}" and return if !session[:user_id].nil?
    end

    if not located? and params[:location]
      location = Core::Location.find(params[:location]) rescue nil
      self.current_location = location if location
    end

    if not located? and session[:sso_location]
      location = Core::Location.find(session[:sso_location]) rescue nil
      self.current_location = location if location
    end

    located? || location_denied

  end

  def set_return_uri
    if params[:return_uri]
      session[:return_uri] = params[:return_uri]
    end
  end

  def located?
    self.current_location
  end

  # Redirect as appropriate when an access request fails.
  #
  # The default action is to redirect to the location screen.
  def location_denied
    respond_to do |format|
      format.html do
        store_location
        redirect_to '/location'
      end
    end
  end

  # Store the URI of the current request in the session.
  #
  # We can return to this location by calling #redirect_back_or_default.
  def store_location
    session[:return_to] = request.request_uri
  end

  # Redirect to the URI stored by the most recent store_location call or
  # to the passed default.  Set an appropriately modified
  #   after_filter :store_location, :only => [:index, :new, :show, :edit]
  # for any controller you want to be bounce-backable.
  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end

  # Accesses the current user from the session.
  # Future calls avoid the database because nil is not equal to false.
  def current_location
    @current_location ||= location_from_session unless @current_location == false
    Core::Location.current_location = @current_location unless @current_location == false
    @current_location
  end

  # Store the given location id in the session.
  def current_location=(new_location)
    session[:location_id] = new_location ? new_location.id : nil
    @current_location = new_location || false
  end

  # Called from #current_location.  First attempt to get the location id stored in the session.
  def location_from_session
    self.current_location = Core::Location.find_by_location_id(session[:location_id]) if session[:location_id]
  end

  def set_current_user

    if !session[:user_id].nil?
      current_user = Core::User.find(session[:user_id])
    end

    Core::User.current = current_user

  end

  def print_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    @patient_id = patient_id
    render :template => 'print/print', :layout => nil
  end

  def print_location_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    render :template => 'print/print_location', :layout => nil
  end

  def check_encounter(patient, enc, current_date = Date.today)
    Core::Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                   :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  current_date.to_date.to_date, patient.id,Core::EncounterType.find_by_name(enc).id])
  end

  def next_task(patient)
    session_date = session[:datetime].to_date rescue Date.today
    task = TaskFlow.new(session[:user_id], patient.id, session_date).next_task rescue nil
    begin
      return task.url if !task.nil?
      return "/patients/show/#{patient.id}"
    rescue
      return "/patients/show/#{patient.id}"
    end
  end

  def current_program
    if session[:selected_program].blank?
      return "HYPERTENSION PROGRAM"
    end
    return session[:selected_program]
  end

  def is_first_hypertension_clinic_visit(patient_id)
    session_date = session[:datetime].to_date rescue Date.today
    hyp_encounter = Core::Encounter.find(:first,:conditions =>["voided = 0 AND patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) < ?",
                                                         patient_id, Core::EncounterType.find_by_name('DIABETES HYPERTENSION INITIAL VISIT').id, session_date ]) #rescue []
    return true if hyp_encounter.blank?
    return false
  end

protected

  def authenticate_user

    token = session[:token] rescue nil

    if token.nil?
      redirect_to "/core_user_management/login" and return
    else
      @user = CoreUser.find(session[:user_id]) rescue nil

      if @user.nil?
        redirect_to "/core_user_management/login" and return
      end
    end

  end

end
