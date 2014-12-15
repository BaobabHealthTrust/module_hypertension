module Core
  class OrderType < ActiveRecord::Base
    set_table_name :order_type
    set_primary_key :order_type_id
    include Core::Openmrs
  end
end