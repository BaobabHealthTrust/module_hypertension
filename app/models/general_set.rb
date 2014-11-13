class GeneralSet < ActiveRecord::Base
  set_table_name "dset"
  set_primary_key "set_id"

  has_many :drug_sets, :foreign_key => :set_id, :conditions => {:voided => 0}

  def activate(date)

    if self.status != "active"

      self.update_attributes(:status => "active")
      self.update_attributes(:date_updated => date) if !date.blank?
    end
  end

  def deactivate(date)

    if self.status != "inactive"
      
      self.update_attributes(:status => "inactive")
      self.update_attributes(:date_updated => date) if !date.blank?
    end
  end

  def block(date)

    if self.status != "blocked"

      self.update_attributes(:status => "blocked")
      self.update_attributes(:date_updated => date) if !date.blank?
    end
  end

end
