class GlobalProperty < ActiveRecord::Base
  set_table_name "global_property"
  set_primary_key "property"
  include Openmrs

  def to_s
    return "#{property}: #{property_value}"
  end

  def self.get_global_property_value(global_property)

    property_value = GlobalProperty.find(:first, :conditions => {:property => "#{global_property}"}
    ).property_value rescue nil

   return property_value
  end

end
