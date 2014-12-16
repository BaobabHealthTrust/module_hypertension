class DrugSet < ActiveRecord::Base
  set_table_name "drug_set"
  set_primary_key "drug_set_id"

  belongs_to :dset, :foreign_key => :set_id

  def void

    self.update_attributes(:voided => 1)
  end
end
