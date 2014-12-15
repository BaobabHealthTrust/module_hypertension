module Core
  class GlobalProperty < ActiveRecord::Base
    set_table_name "global_property"
    set_primary_key "property"
    include Core::Openmrs

    def to_s
      return "#{property}: #{property_value}"
    end

  end
end