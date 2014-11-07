ActionController::Routing::Routes.draw do |map|
	map.devise_for :users
  
  # ------------------------------- INSTALLATION GENERATED ----------------------------------------------------
  map.root :controller => "dde"
  map.clinic  '/clinic', :controller => 'dde', :action => 'index'
  map.duplicates  '/duplicates', :controller => 'dde', :action => 'duplicates'
  map.dde_search_by_name  '/dde_search_by_name', :controller => 'dde', :action => 'search_by_name'
  map.dde_search_by_id  '/dde_search_by_id', :controller => 'dde', :action => 'search_by_id'
  map.push_merge  '/push_merge', :controller => 'dde', :action => 'push_merge'
  map.process_result '/process_result', :controller => 'dde', :action => 'process_result'
  map.process_data '/process_data/:id', :controller => 'dde', :action => 'process_data'
  map.search '/search', :controller => 'dde', :action => 'search_name'
  map.new_patient '/new_patient', :controller => 'dde', :action => 'new_patient'
  map.ajax_process_data '/ajax_process_data', :controller => 'dde', :action => {'ajax_process_data' => [:post]}
  map.process_confirmation '/process_confirmation', :controller => 'dde', :action => {'process_confirmation' => [:post]}
  map.patient_not_found '/patient_not_found/:id', :controller => 'dde', :action => 'patient_not_found'
  map.ajax_search '/ajax_search', :controller => 'dde', :action => 'ajax_search'
  map.edit_demographics '/patients/edit_demographics', :controller => 'dde', :action => 'edit_patient'
  map.demographics '/people/demographics/:id', :controller => 'dde', :action => 'edit_patient'
  map.demographics '/patients/demographics/:id', :controller => 'dde', :action => 'edit_patient'
  # ------------------------------- END OF INSTALLATION GENERATED ----------------------------------------------
  
 #   map.root :controller => "clinic"

 #   map.clinic  '/clinic', :controller => 'clinic', :action => 'index'  
  
	map.login  '/login', :controller => 'core_user_management', :action => 'login'
	map.logout '/logout', :controller => 'core_user_management', :action => 'logout'
	map.location '/location', :controller => 'core_user_management', :action => 'location'
		
  map.set_datetime '/set_datetime', :controller => 'clinic', :action => 'set_datetime'

  map.update_datetime '/update_datetime', :controller => 'clinic', :action => 'update_datetime'

  map.reset_datetime '/reset_datetime', :controller => 'clinic', :action => 'reset_datetime'

  map.overview '/overview', :controller => 'clinic', :action => 'overview'

  map.reports '/reports', :controller => 'clinic', :action => 'reports'

  map.my_account '/my_account', :controller => 'clinic', :action => 'my_account'

  map.administration '/administration', :controller => 'clinic', :action => 'administration'

  map.project_users '/project_users', :controller => 'clinic', :action => 'project_users'

  map.project_users_list '/project_users_list', :controller => 'clinic', :action => 'project_users_list'

  map.add_to_project '/add_to_project', :controller => 'clinic', :action => 'add_to_project'

  map.remove_from_project '/remove_from_project', :controller => 'clinic', :action => 'remove_from_project'

  map.manage_activities '/manage_activities', :controller => 'clinic', :action => 'manage_activities'

  map.check_role_activities '/check_role_activities', :controller => 'clinic', :action => 'check_role_activities'

  map.create_role_activities '/create_role_activities', :controller => 'clinic', :action => 'create_role_activities'

  map.remove_role_activities '/remove_role_activities', :controller => 'clinic', :action => 'remove_role_activities'

  map.project_members '/project_members', :controller => 'clinic', :action => 'project_members'

  map.my_activities '/my_activities', :controller => 'clinic', :action => 'my_activities'

  map.check_user_activities '/check_user_activities', :controller => 'clinic', :action => 'check_user_activities'

  map.create_user_activity '/create_user_activity', :controller => 'clinic', :action => 'create_user_activity'

  map.remove_user_activity '/remove_user_activity', :controller => 'clinic', :action => 'remove_user_activity'

  map.demographics_fields '/demographics_fields', :controller => 'clinic', :action => 'demographics_fields'

  map.show_selected_fields '/show_selected_fields', :controller => 'clinic', :action => 'show_selected_fields'

  map.add_field '/add_field', :controller => 'clinic', :action => 'add_field'

  map.remove_field '/remove_field', :controller => 'clinic', :action => 'remove_field'

  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
