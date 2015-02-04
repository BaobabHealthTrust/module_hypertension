ActionController::Routing::Routes.draw do |map|
  map.root :controller => "clinic"

  map.clinic  '/clinic', :controller => 'clinic', :action => 'index'
  
	map.login  '/login', :controller => 'sessions', :action => 'new'
	map.logout '/logout', :controller => 'sessions', :action => 'destroy'
	map.location '/location', :controller => 'sessions', :action => 'location'
	
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

  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
