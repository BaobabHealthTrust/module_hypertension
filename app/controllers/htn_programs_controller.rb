class HtnProgramsController < ApplicationController
	unloadable

  def locations
    #Code re-use from BART2
    search = params[:q] || ''
    unless search.blank?
      @locations = Location.find(:all, :conditions=>["location.retired = 0 AND name LIKE ?", "#{search}%"], :limit => 10)
    else
        search = params[:q] || ''
        location_tag_id = LocationTag.find_by_name("#{params[:transfer_type]}").id rescue nil
        unless location_tag_id.blank?
          location_ids = LocationTagMap.find(:all,:conditions => ["location_tag_id = (?)",location_tag_id]).map{|e|e.location_id}
          @locations = Location.find(:all, :conditions=>["location.retired = 0 AND location_id IN (?) AND name LIKE ? AND name != ''", location_ids, "#{search}%"])
        else
          @locations = most_common_locations(params[:q] || '')
        end
    end

    @names = @locations.map do | location |
      next if generic_locations.include?(location.name)
      "<li value='#{location.name}'>#{location.name}</li>"
    end
    render :text => @names.join('')
  end

  def most_common_locations(search)
    return (Location.find_by_sql([
      "SELECT DISTINCT location.name AS name, location.location_id AS location_id \
       FROM location \
       WHERE location.retired = 0 AND name LIKE ? AND name != '' \
       ORDER BY name ASC \
       LIMIT 10",
       "%#{search}%"])).uniq
  end
end
