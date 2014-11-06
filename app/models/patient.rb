class Patient < ActiveRecord::Base
  set_table_name "patient"
  set_primary_key "patient_id"
  include Openmrs

  has_one :person, :foreign_key => :person_id, :conditions => {:voided => 0}
  has_many :patient_identifiers, :foreign_key => :patient_id, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :patient_programs, :conditions => {:voided => 0}
  has_many :programs, :through => :patient_programs
  has_many :relationships, :foreign_key => :person_a, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :orders, :conditions => {:voided => 0}
  has_many :encounters, :conditions => {:voided => 0} do 

 def find_by_date(encounter_date)
      encounter_date = Date.today unless encounter_date
      find(:all, :conditions => ["encounter_datetime BETWEEN ? AND ?", 
           encounter_date.to_date.strftime('%Y-%m-%d 00:00:00'), 
           encounter_date.to_date.strftime('%Y-%m-%d 23:59:59')
      ]) # Use the SQL DATE function to compare just the date part
    end
  end

  def after_void(reason = nil)
    self.person.void(reason) rescue nil
    self.patient_identifiers.each {|row| row.void(reason) }
    self.patient_programs.each {|row| row.void(reason) }
    self.orders.each {|row| row.void(reason) }
    self.encounters.each {|row| row.void(reason) }
  end
  
def physical_address
    return PersonAddress.find_by_person_id(self.id, :conditions => "voided = 0").city_village rescue nil
end

def name
    "#{self.person.names[0].given_name rescue ''} #{self.person.names[0].family_name rescue ''}"
end

def self.duplicates(attributes)
    search_str = ''
    ( attributes.sort || [] ).each do | attribute |
      search_str+= ":#{attribute}" unless search_str.blank?
      search_str = attribute if search_str.blank?
    end rescue []

    return if search_str.blank?
    duplicates = {}
    patients = Patient.find(:all) # AND DATE(date_created >= ?) AND DATE(date_created <= ?)",
              #'2005-01-01'.to_date,'2010-12-31'.to_date])

    ( patients || [] ).each do | patient |
      if search_str.upcase == "DOB:NAME"
        next if patient.name.blank?
        next if patient.person.birthdate.blank?
        duplicates["#{patient.name}:#{patient.person.birthdate}"] = [] if duplicates["#{patient.name}:#{patient.person.birthdate}"].blank?
        duplicates["#{patient.name}:#{patient.person.birthdate}"] << patient
      elsif search_str.upcase == "DOB:ADDRESS"
        next if patient.physical_address.blank?
        next if patient.person.birthdate.blank?
        duplicates["#{patient.name}:#{patient.physical_address}"] = [] if duplicates["#{patient.name}:#{patient.physical_address}"].blank?
        duplicates["#{patient.name}:#{patient.physical_address}"] << patient
      elsif search_str.upcase == "DOB:LOCATION (PHYSICAL)"
        next if patient.person.birthdate.blank?
        next if patient.person.addresses.last.county_district.blank?
        duplicates["#{patient.person.addresses.last.county_district}:#{patient.physical_address}"] = [] if duplicates["#{patient.person.addresses.last.county_district}:#{patient.physical_address}"].blank?
        duplicates["#{patient.person.addresses.last.county_district}:#{patient.physical_address}"] << patient
      elsif search_str.upcase == "ADDRESS:DOB"
        next if patient.person.birthdate.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.person.birthdate}"].blank?
          duplicates["#{patient.physical_address}:#{patient.person.birthdate}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.person.birthdate}"] << patient
      elsif search_str.upcase == "ADDRESS:LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "ADDRESS:NAME"
        next if patient.name.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.name}"].blank?
          duplicates["#{patient.physical_address}:#{patient.name}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.name}"] << patient
      elsif search_str.upcase == "ADDRESS:LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "DOB:LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        next if patient.person.birthdate.blank?
        if duplicates["#{patient.person.birthdate}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.person.birthdate}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.person.birthdate}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "LOCATION (PHYSICAL):NAME"
        next if patient.name.blank?
        next if patient.person.addresses.last.county_district.blank?
        if duplicates["#{patient.person.addresses.last.county_district}:#{patient.name}"].blank?
          duplicates["#{patient.person.addresses.last.county_district}:#{patient.name}"] = []
        end
        duplicates["#{patient.person.addresses.last.county_district}:#{patient.name}"] << patient
      elsif search_str.upcase == "ADDRESS:DOB:LOCATION (PHYSICAL):NAME"
        next if patient.name.blank?
        next if patient.person.birthdate.blank?
        next if patient.physical_address.blank?
        next if patient.person.addresses.last.county_district.blank?
        if duplicates["#{patient.name}:#{patient.person.birthdate}:#{patient.physical_address}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.name}:#{patient.person.birthdate}:#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.name}:#{patient.person.birthdate}:#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "ADDRESS"
        next if patient.physical_address.blank?
        if duplicates[patient.physical_address].blank?
          duplicates[patient.physical_address] = []
        end
        duplicates[patient.physical_address] << patient
      elsif search_str.upcase == "DOB"
        next if patient.person.birthdate.blank?
        if duplicates[patient.person.birthdate].blank?
          duplicates[patient.person.birthdate] = []
        end
        duplicates[patient.person.birthdate] << patient
      elsif search_str.upcase == "LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        if duplicates[patient.person.addresses.last.county_district].blank?
          duplicates[patient.person.addresses.last.county_district] = []
        end
        duplicates[patient.person.addresses.last.county_district] << patient
      elsif search_str.upcase == "NAME"
        next if patient.name.blank?
        if duplicates[patient.name].blank?
          duplicates[patient.name] = []
        end
        duplicates[patient.name] << patient
      end
    end
    hash_to = {}
    duplicates.each do |key,pats |
      next unless pats.length > 1
      hash_to[key] = pats
    end
    hash_to
   end
   
def self.merge(patient_id, secondary_patient_id)
    patient = Patient.find(patient_id, :include => [:patient_identifiers, :patient_programs, {:person => [:names]}])
    secondary_patient = Patient.find(secondary_patient_id, :include => [:patient_identifiers, :patient_programs, {:person => [:names]}])
    sec_pt_arv_numbers = PatientIdentifier.find(:all, :conditions => ["patient_id =? AND identifier_type =?",
      secondary_patient_id, PatientIdentifierType.find_by_name('ARV NUMBER').id]).map(&:identifier) rescue []

    unless sec_pt_arv_numbers.blank?
      sec_pt_arv_numbers.each do |arv_number|
        ActiveRecord::Base.connection.execute("
          UPDATE patient_identifier SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
          void_reason = 'merged with patient #{patient_id}'
          WHERE patient_id = #{secondary_patient_id}
          AND identifier = '#{arv_number}'")
      end
    end
    
  ActiveRecord::Base.transaction do
    secondary_patient.patient_identifiers.each {|r|
      if patient.patient_identifiers.map(&:identifier).each{| i | i.upcase }.include?(r.identifier.upcase)
        ActiveRecord::Base.connection.execute("
          UPDATE patient_identifier SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
          void_reason = 'merged with patient #{patient_id}'
          WHERE patient_id = #{secondary_patient_id}
          AND identifier_type = #{r.identifier_type}
          AND identifier = '#{r.identifier}'")
      else
        ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_identifier SET patient_id = #{patient_id}
WHERE patient_id = #{secondary_patient_id}
AND identifier_type = #{r.identifier_type}
AND identifier = "#{r.identifier}"
EOF
      end
    }

    secondary_patient.person.names.each {|r|
      if patient.person.names.map{|pn| "#{pn.given_name.upcase rescue ''} #{pn.family_name.upcase rescue ''}"}.include?("#{r.given_name.upcase rescue ''} #{r.family_name.upcase rescue ''}")
      ActiveRecord::Base.connection.execute("
        UPDATE person_name SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE person_id = #{secondary_patient_id}
        AND person_name_id = #{r.person_name_id}")
      end
    }

    secondary_patient.person.addresses.each {|r|
      if patient.person.addresses.map{|pa| "#{pa.city_village.upcase rescue ''}"}.include?("#{r.city_village.upcase rescue ''}")
      ActiveRecord::Base.connection.execute("
        UPDATE person_address SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE person_id = #{secondary_patient_id}")
      else
        ActiveRecord::Base.connection.execute <<EOF
UPDATE person_address SET person_id = #{patient_id}
WHERE person_id = #{secondary_patient_id}
AND person_address_id = #{r.person_address_id}
EOF
      end
    }

    secondary_patient.patient_programs.each {|r|
      if patient.patient_programs.map(&:program_id).include?(r.program_id)
      ActiveRecord::Base.connection.execute("
        UPDATE patient_program SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE patient_id = #{secondary_patient_id}
        AND patient_program_id = #{r.patient_program_id}")
      else
        ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_program SET patient_id = #{patient_id}
WHERE patient_id = #{secondary_patient_id}
AND patient_program_id = #{r.patient_program_id}
EOF
      end
    }

    ActiveRecord::Base.connection.execute("
        UPDATE patient SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE patient_id = #{secondary_patient_id}")

    ActiveRecord::Base.connection.execute("UPDATE person_attribute SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE person_address SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE encounter SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE obs SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE note SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
    #ActiveRecord::Base.connection.execute("UPDATE person SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
  end
end

def self.vl_result_hash(patient)
    encounter_type = EncounterType.find_by_name("REQUEST").id
    viral_load = Concept.find_by_name("Hiv viral load").concept_id
    identifier_type = ["Legacy Pediatric id","National id","Legacy National id","Old Identification Number"]
    identifier_types = PatientIdentifierType.find(:all,
      :conditions=>["name IN (?)",identifier_type]
    ).collect{| type |type.id }

    identifiers = []
    PatientIdentifier.find(:all, :conditions=>["patient_id=? AND identifier_type IN (?)",
        patient.id,identifier_types]).each{| i | identifiers << i.identifier }
    national_ids = identifiers
    vl_hash = {}
    results = Lab.find_by_sql(["
        SELECT * FROM Lab_Sample s
        INNER JOIN Lab_Parameter p ON p.sample_id = s.sample_id
        INNER JOIN codes_TestType c ON p.testtype = c.testtype
        INNER JOIN (SELECT DISTINCT rec_id, short_name FROM map_lab_panel) m ON c.panel_id = m.rec_id
        WHERE s.patientid IN (?)
        AND short_name = ?
        AND s.deleteyn = 0
        AND s.attribute = 'pass'", national_ids, 'HIV_viral_load'
    ]).collect do | result |
            [
              result.Sample_ID,
              result.Range,
              result.TESTVALUE,
              result.TESTDATE
            ]
    end

    results.each do |result|

      accession_number = result[0]
      vl_result = result[2]
      date_of_sample = result[3].to_date
      
      vl_hash[accession_number] = {} if vl_hash[accession_number].blank?
      vl_hash[accession_number]["result"] = {} if vl_hash[accession_number]["result"].blank?
      vl_hash[accession_number]["result"] = vl_result
      vl_hash[accession_number]["date_of_sample"] = {} if vl_hash[accession_number]["date_of_sample"].blank?
      vl_hash[accession_number]["date_of_sample"] = date_of_sample

      vl_lab_sample_obs = Observation.find(:last, :joins => [:encounter], :conditions => ["
        person_id =? AND encounter_type =? AND concept_id =? AND accession_number =?
        AND value_text LIKE (?)",
        patient.id, encounter_type, viral_load, accession_number.to_i, '%Result given to patient%']) rescue nil
    
      unless vl_lab_sample_obs.blank?
        vl_hash[accession_number]["result_given"] = {} if vl_hash[accession_number]["result_given"].blank?
        vl_hash[accession_number]["result_given"] = "yes"
        vl_hash[accession_number]["date_result_given"] = {} if vl_hash[accession_number]["date_result_given"].blank?
        vl_hash[accession_number]["date_result_given"] = vl_lab_sample_obs.value_datetime.to_date
      else
        vl_hash[accession_number]["result_given"] = {} if vl_hash[accession_number]["result_given"].blank?
        vl_hash[accession_number]["result_given"] = "no"
        vl_hash[accession_number]["date_result_given"] = {} if vl_hash[accession_number]["date_result_given"].blank?
        vl_hash[accession_number]["date_result_given"] = ""
      end

    switched_to_second_line_obs = Observation.find(:last, :joins => [:encounter], :conditions => ["
        person_id =? AND encounter_type =? AND concept_id =? AND accession_number =?
        AND value_text LIKE (?)",
        patient.id, encounter_type, viral_load, accession_number.to_i, '%Patient switched to second line%']) rescue nil
    
    unless switched_to_second_line_obs.blank?
      vl_hash[accession_number]["second_line_switch"] = {} if vl_hash[accession_number]["second_line_switch"].blank?
      vl_hash[accession_number]["second_line_switch"] = "yes"
    else
      vl_hash[accession_number]["second_line_switch"] = {} if vl_hash[accession_number]["second_line_switch"].blank?
      vl_hash[accession_number]["second_line_switch"] = "no"
    end

    end
    
    return vl_hash.sort_by{|key, value|value["date_of_sample"].to_date}.reverse rescue {}
end
 def eligible_for_htn_diagnosis
  #this method serves to show if a patient is eligibile for HTN
  if self.person.age > GlobalProperty.get_global_property_value("htn.age.threshold").to_i
   #need to add condition to check that the check after one year condition is not effective
   return true
  end
  return false
 end

end
