module Core
  class RelationshipType < ActiveRecord::Base
    set_table_name :relationship_type
    set_primary_key :relationship_type_id
    include Core::Openmrs
    default_scope :order => 'weight DESC'
    has_many :relationships, :class_name => 'Core::Relationship', :conditions => {:voided => 0}
  end
end