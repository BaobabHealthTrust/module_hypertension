ActionController::Routing::Routes.draw do |map|
  map.root :controller => "clinic"

  map.clinic  '/clinic', :controller => 'clinic', :action => 'index'
  
	map.login  '/login', :controller => 'sessions', :action => 'new'
	map.logout '/logout', :controller => 'sessions', :action => 'destroy'
	map.location '/location', :controller => 'sessions', :action => 'location'
	
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
