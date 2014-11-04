class ValidationResult < ActiveRecord::Base
  belongs_to :validation_rule, :foreign_key => "rule_id"
end
