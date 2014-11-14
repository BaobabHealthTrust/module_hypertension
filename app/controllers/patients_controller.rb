class PatientsController < ApplicationController

  before_filter :find_patient

  def show
    @patient = Core::Patient.find(params[:id] || params[:patient_id]) # rescue nil

    @retrospective = session[:datetime]
    @retrospective = Time.now if session[:datetime].blank?

    @user = Core::User.current rescue nil

    session[:patient_id] = @patient.id
    session[:user_id] = @user.id
    # session[:location_id] = params[:location_id]

    program_id = Core::Program.find_by_name('CHRONIC CARE PROGRAM').id
    date = Date.today
    @current_state = Core::PatientState.find_by_sql("SELECT p.patient_id, current_state_for_program(p.patient_id, #{program_id}, '#{date}') AS state, c.name as status FROM patient p
                      INNER JOIN  patient_program pp on pp.patient_id = p.patient_id
                      inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                      INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{program_id}, '#{date}')
                      INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                      WHERE DATE(ps.start_date) <= '#{date}'
                      AND p.patient_id = #{@patient.id}").first.status rescue ""


    @links = {}

    @project = get_global_property_value("project.name") rescue "Unknown"

    @task = TaskFlow.new(params[:user_id], @patient.id).next_task

    # render :layout => false
  end

  def blank
    render :layout => false
  end

  def current_visit
    @retrospective = session[:datetime]
    @retrospective = Time.now if session[:datetime].blank?


    @patient = Core::Patient.find(params[:id] || params[:patient_id]) # rescue nil

    Core::ProgramEncounter.current_date = @retrospective

    @programs = @patient.program_encounters.find(:all, :conditions => ["DATE(date_time) = ?", @retrospective.to_date],
                                                 :order => ["date_time DESC"]).collect { |p|

      [
          p.id,
          p.to_s,
          p.program_encounter_types.collect { |e|
            [
                e.encounter_id, e.encounter.type.name,
                (e.encounter.encounter_datetime.strftime("%H:%M") rescue []),
                (e.encounter.creator rescue "")
            ]
          },
          p.date_time.strftime("%d-%b-%Y")
      ]
    } if !@patient.nil?

    render :layout => false
  end

  def visit_history
    @patient = Core::Patient.find(params[:id] || params[:patient_id]) rescue nil

    @programs = @patient.program_encounters.find(:all, :order => ["date_time DESC"]).collect { |p|

      [
          p.id,
          p.to_s,
          p.program_encounter_types.collect { |e|
            [
                e.encounter_id, e.encounter.type.name,
                (e.encounter.encounter_datetime.strftime("%H:%M") rescue ""),
                (e.encounter.creator rescue "")
            ]
          },
          p.date_time.strftime("%d-%b-%Y")
      ]
    } if !@patient.nil?

    # raise @programs.inspect

    render :layout => false
  end

  def patient_bp
    patient = Core::Patient.find(params[:patient_id])
    @bps = Core::Observation.find(:all,
                                  :conditions => ["person_id = ? AND concept_id = ?", params[:patient_id], Core::ConceptName.find_by_name("systolic blood pressure").concept_id], :order => "obs_datetime DESC", :limit => 5).collect { |o|
      [calculate_bp(patient, o.obs_datetime).split("/")[0].to_i,
       o.obs_datetime.to_date.strftime('%Y/%m/%d'),
       calculate_bp(patient, o.obs_datetime).split("/")[1].to_i,
       (calculate_bp(patient, o.obs_datetime).split("/")[0].to_f / calculate_bp(patient, o.obs_datetime).split("/")[1].to_f).to_f.round(2)] }
    #raise @bps.to_yaml


    @bps = @bps.sort_by { |atr| atr[1] }.to_json
    render :partial => 'bp_chart' and return
  end

  def patient_report
    @user = Core::User.find(params[:user_id]) rescue nil
    @patient = Core::Patient.find(params[:patient_id] || params[:id]) rescue nil
    type = Core::EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Core::Order.find(:all,
                                      :joins => "INNER JOIN encounter e USING (encounter_id)",
                                      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
                                                      type.id, @patient.id, session_date])

    @restricted = Core::ProgramLocationRestriction.all(:conditions => {:location_id => Core::Location.current_health_center.id})

    @restricted.each do |restriction|
      @prescriptions = restriction.filter_orders(@prescriptions)
    end

    @encounters = @patient.encounters.find_by_date(session_date)

    @transfer_out_site = nil

    @encounters.each do |enc|
      enc.observations.map do |obs|
        @transfer_out_site = obs.to_s if obs.to_s.include?('Transfer out to')
      end
    end
    @sbp = current_vitals(@patient, "systolic blood pressure").to_s.split(':')[1].squish rescue 0
    @dbp = current_vitals(@patient, "diastolic blood pressure").to_s.split(':')[1].squish rescue 0

    @complications = Vitals.current_encounter(@patient, "complications", "complications") rescue []

    @diabetic = Core::ConceptName.find_by_concept_id(Vitals.get_patient_attribute_value(@patient, "Patient has Diabetes")).name rescue []

    @risk = Vitals.current_encounter(@patient, "assessment", "assessment comments") rescue []

    #raise @prescriptions.to_yaml
    @programs = @patient.program_encounters.current.collect { |p|

      [
          p.id,
          p.to_s,
          p.program_encounter_types.collect { |e|
            [
                e.encounter_id, e.encounter.type.name,
                (e.encounter.encounter_datetime.strftime("%H:%M") rescue ""),
                (e.encounter.creator rescue "")
            ]
          },
          p.date_time.strftime("%d-%b-%Y")
      ]
    } if !@patient.nil?
    #@reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    #@arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')

    render :layout => false
  end

  def printouts
    @user = Core::User.find(params[:user_id]) rescue nil
    @patient = Core::Patient.find(params[:patient_id] || params[:id]) rescue nil
    render :layout => false
  end

  def dashboard_print_national_id
    print_and_redirect("/patients/national_id_label?patient_id=#{params[:patient_id]}&user_id=#{params[:user_id]}", "/patients/show?patient_id=#{params[:patient_id]}&user_id=#{params[:user_id]}")
  end

  def national_id_label
    print_string = patient_national_id_label(@patient) # rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string, :type => "application/label; charset=utf-8", :stream => false, :filename => "#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def patient_national_id_label(patient)
    patient_bean = patient.person
    national_id = patient.national_id_with_dashes
    sex = patient_bean.gender.match(/F/i) ? "(F)" : "(M)"
    address = patient.person.address.strip[0..24].humanize rescue ""
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50, 180, 0, 1, 5, 15, 120, false, "#{national_id}")
    label.draw_multi_text("#{patient.name.titleize}")
    label.draw_multi_text("#{national_id} #{patient_bean.birthdate}#{sex}")
    label.draw_multi_text("#{address}")
    label.print(1)
  end

  def specific_patient_visit_date_label

    session_date = params[:session_date].to_date rescue Date.today
    @patient = Core::Patient.find(params[:patient_id]) rescue Core::Patient.find(params[:id]) rescue []

    print_string = patient_visit_label(@patient, session_date) #rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")

    send_data(print_string, :type => "application/label; charset=utf-8", :stream => false, :filename => "#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def patient_visit_label(patient, date = Date.today)
    #result = Location.find(session[:location_id]).name.match(/outpatient/i)
    visit = visits(patient, date)[date] #rescue {}
    results = lab_results(patient.id, date)
    return if visit.blank?
    visit_data = mastercard_visit_data(visit)

    label = ZebraPrinter::StandardLabel.new

    label.draw_text("#{patient.name}(#{patient.gender})", 25, 60, 0, 3, 1, 1, false)
    label.draw_text("#{visit.height + 'cm' if !visit.height.blank?}  #{visit.weight + 'kg' if !visit.weight.blank?}  #{'BMI:' + visit.bmi if !visit.bmi.blank?}  #{'BP :' + visit_data['bp'] }", 25, 95, 0, 2, 1, 1, false) rescue ""

    line = 25
    (results || []).each { |sugar|
      label.draw_text("#{sugar}", line, 120, 0, 2, 1, 1, false)
      line += 205
    }
    label.draw_text("Drug(s) Dispensed", 25, 150, 0, 3, 1, 1, false)
    #label.draw_text("DU",700,150,0,3,1,1,false)
    #label.draw_text("FN",600,150,0,3,1,1,false)
    #label.draw_text("Dose",500,150,0,3,1,1,false)
    label.draw_line(25, 170, 800, 5)
    starting_index = 25
    start_line = 180
    starting_line = 180

    visit.gave.each { |values|
      data = values #.last.split(";")
      next if data.blank?
      bold = false
      label.draw_text("#{data}", 25, starting_line, 0, 2, 1, 1, bold)
      # label.draw_text("#{data[1]}",600,starting_line,0,2,1,1,bold)
      # label.draw_text("#{data[2]}",700,starting_line,0,2,1,1,bold)
      # label.draw_text("#{data[3]}",500,starting_line,0,2,1,1,bold)
      starting_line = starting_line + 20
    } rescue []

    starting_line = starting_line + 10
    label.draw_line(25, starting_line, 800, 5)
    starting_line = starting_line + 10
    if life_style(patient.id, date).blank?
      label.draw_text("Life Style Given: No", 25, starting_line, 0, 1, 1, 1, false)
    else
      label.draw_text("Life Style Given: Yes", 25, starting_line, 0, 1, 1, 1, false)
    end
    label.draw_text("#{seen_by(patient, date)}", 597, starting_line, 0, 1, 1, 1, false)
    starting_line = starting_line + 20
    label.draw_text("#{visit_data['next_appointment']}", 30, starting_line, 0, 2, 1, 1, false) if visit_data['next_appointment']

    #starting_line = starting_line + 20
    label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}", 597, starting_line, 0, 1, 1, 1, false)


    label.print(2)
    #end
  end

  def visits(patient_obj, encounter_date = nil, prescribed = false)
    patient_visits = {}
    yes = Core::ConceptName.find_by_name("YES")
    concept_names = ["APPOINTMENT DATE", "HEIGHT (CM)", 'WEIGHT (KG)',
                     "BODY MASS INDEX, MEASURED", "RESPONSIBLE PERSON PRESENT",
                     "AMOUNT DISPENSED", "PRESCRIBE DRUGS",
                     "DRUG INDUCED", "AMOUNT OF DRUG BROUGHT TO CLINIC",
                     "WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER",
                     "CLINICAL NOTES CONSTRUCT", "ASSESSMENT COMMENTS"]
    concept_ids = Core::ConceptName.find(:all, :conditions => ["name in (?)", concept_names]).map(&:concept_id)

    if encounter_date.blank?
      observations = Core::Observation.find(:all,
                                      :conditions => ["voided = 0 AND person_id = ? AND concept_id IN (?)",
                                                      patient_obj.patient_id, concept_ids],
                                      :order => "obs_datetime").map { |obs| obs if !obs.concept.nil? }
    else
      observations = Core::Observation.find(:all,
                                      :conditions => ["voided = 0 AND person_id = ? AND Date(obs_datetime) = ? AND concept_id IN (?)",
                                                      patient_obj.patient_id, encounter_date.to_date, concept_ids],
                                      :order => "obs_datetime").map { |obs| obs if !obs.concept.nil? }
    end

    if prescribed == true
      visit_date = encounter_date.to_date
      patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?
      patient_visits[visit_date].gave = []
      type = Core::EncounterType.find_by_name('TREATMENT')
      prescriptions = Core::Order.find(:all,
                                 :joins => "INNER JOIN encounter e USING (encounter_id)",
                                 :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(start_date) = ?",
                                                 type.id, patient_obj.patient_id, visit_date.to_date])

      prescriptions.each { |drug_name|
        drug_given_name = drug_name.drug_order.drug.name
        frequency = drug_name.drug_order.frequency
        dose = drug_name.drug_order.dose
        daily_dose = drug_name.drug_order.equivalent_daily_dose
        duration = (drug_name.drug_order.amount_needed / daily_dose).to_i

        patient_visits[visit_date].gave << ["#{drug_name.drug_order.amount_needed}#{drug_name.drug_order.drug.units}:#{drug_given_name};#{dose}(#{doses_per_day(frequency)}) for #{duration} days"]
      }
    else
      type = Core::EncounterType.find_by_name('TREATMENT')
      concept_id = Core::ConceptName.find_by_name("Amount dispensed").concept_id
      if !encounter_date.blank?
        visit_date = encounter_date.to_date
        patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?
        patient_visits[visit_date].gave = []

        obs = Core::Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ? AND voided = 0",
                                                     patient_obj.patient_id, concept_id, visit_date.to_date]).collect { |r| r.value_drug }.uniq

        patient_visits[visit_date].gave = []
        obs.each { |drug_id|

          drug = Core::Drug.find(drug_id)
          drug_given_name = drug.name
          drugs_given_uniq = Hash.new(0)
          Core::Observation.find(:all, :conditions => ["value_drug = ? AND person_id = ? AND concept_id = ?",
                                                 drug_id, patient_obj.patient_id, concept_id]).each { |given|
            drugs_given_uniq[drug_given_name] += given.value_numeric
          }
          (drugs_given_uniq || {}).each do |drug_name, quantity_given|
            patient_visits[visit_date].gave << ["#{drug_name} #{quantity_given} #{drug.units}"]
          end
        }
      else
        observations.each { |obs|
          visit_date = obs.obs_datetime.to_date
          patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?
          patient_visits[visit_date].gave = []
          obs = Core::Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ? AND voided = 0",
                                                       patient_obj.patient_id, concept_id, visit_date.to_date]).collect { |r| r.value_drug }.uniq

          patient_visits[visit_date].gave = []
          obs.each { |drug_id|

            drug = Core::Drug.find(drug_id)
            drug_given_name = drug.name
            drugs_given_uniq = Hash.new(0)
            Core::Observation.find(:all, :conditions => ["value_drug = ? AND person_id = ? AND concept_id = ?",
                                                   drug_id, patient_obj.patient_id, concept_id]).each { |given|
              drugs_given_uniq[drug_given_name] += given.value_numeric
            }
            (drugs_given_uniq || {}).each do |drug_name, quantity_given|
              patient_visits[visit_date].gave << ["#{drug_name} #{quantity_given} #{drug.units}"]
            end
          }
        }
      end

    end #rescue ""

    gave_hash = Hash.new(0)
    observations.map do |obs|
      drug = Core::Drug.find(obs.order.drug_order.drug_inventory_id) rescue nil
      encounter_name = obs.encounter.name rescue []
      next if encounter_name.blank?
      visit_date = obs.obs_datetime.to_date
      patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?

      patient_visits[visit_date].last_seizures = past_seizure(patient_obj.id, visit_date)
      patient_visits[visit_date].last_seizure_date = past_seizure(patient_obj.id, visit_date, "date")

      patient_visits[visit_date].triggers = "Y"
      concept = Core::ConceptName.find_by_sql("select concept_id from concept_name where name = 'Cause of Seizure' and voided = 0").first.concept_id
      triggers = Core::Observation.find(:all, :order => "obs_datetime DESC,date_created DESC", :conditions => ["DATE(obs_datetime) = ? AND concept_id = ? AND person_id = ?", visit_date, concept, patient_obj.id]) rescue nil
      patient_visits[visit_date].triggers = "N" if triggers.blank?

      patient_visits[visit_date].last_seizure_date = visit_date if patient_visits[visit_date].last_seizure_date.blank?

      patient_visits[visit_date].bp = calculate_bp(patient_obj, visit_date)
      patient_visits[visit_date].smoker = current_vitals(patient_obj, "current smoker", visit_date).to_s.match(/yes/i) rescue nil
      !patient_visits[visit_date].smoker.blank? ? patient_visits[visit_date].smoker = "Y" : patient_visits[visit_date].smoker = "N"

      patient_visits[visit_date].alcohol = current_vitals(patient_obj, "Does the patient drink alcohol?", visit_date).to_s.match(/yes/i) rescue nil
      !patient_visits[visit_date].alcohol.blank? ? patient_visits[visit_date].alcohol = "Y" : patient_visits[visit_date].alcohol = "N"

      patient_visits[visit_date].number = current_vitals(patient_obj, "Number of seizure including current", visit_date).value_numeric.to_i rescue "Unknown"

      patient_visits[visit_date].cva_risk = current_vitals(patient_obj, "assessment comments", visit_date).to_s.split(":")[1] rescue "Unknown"

      patient_visits[visit_date].acuity = "N/A"

      patient_visits[visit_date].fbs = specific_vitals(patient_obj, "fasting", visit_date).obs_group_id rescue []
      patient_visits[visit_date].fbs = Core::Observation.find(:all, :conditions => ['obs_group_id = ?', patient_visits[visit_date].fbs]).first.value_numeric.to_i rescue "Not taken"

      patient_visits[visit_date].urine = specific_encounter_with_date(patient_obj, "LAB RESULTS", "serum creatinine", visit_date).first.to_s.split(":")[1].to_i rescue "Not taken"

      program_id = Core::Program.find_by_name('CHRONIC CARE PROGRAM').id

      concept_name = obs.concept.fullname

      if concept_name.upcase == 'APPOINTMENT DATE'
        patient_visits[visit_date].appointment_date = obs.value_datetime
      elsif concept_name.upcase == 'HEIGHT (CM)'
        patient_visits[visit_date].height = obs.answer_string
      elsif concept_name.upcase == 'WEIGHT (KG)'
        patient_visits[visit_date].weight = obs.answer_string
      elsif concept_name.upcase == 'BODY MASS INDEX, MEASURED'
        patient_visits[visit_date].bmi = obs.to_s.split(':')[1].squish rescue ""
      elsif concept_name == 'RESPONSIBLE PERSON PRESENT' or concept_name == 'PATIENT PRESENT FOR CONSULTATION'
        patient_visits[visit_date].visit_by = '' if patient_visits[visit_date].visit_by.blank?
        patient_visits[visit_date].visit_by+= "P" if obs.to_s.squish.match(/Patient present for consultation: Yes/i)
        patient_visits[visit_date].visit_by+= "G" if obs.to_s.squish.match(/Responsible person present: Yes/i)
        #elsif concept_name.upcase == 'TB STATUS'
        #	status = tb_status(patient_obj).upcase rescue nil
        #	patient_visits[visit_date].tb_status = status
        #	patient_visits[visit_date].tb_status = 'noSup' if status == 'TB NOT SUSPECTED'
        #	patient_visits[visit_date].tb_status = 'sup' if status == 'TB SUSPECTED'
        #	patient_visits[visit_date].tb_status = 'noRx' if status == 'CONFIRMED TB NOT ON TREATMENT'
        #	patient_visits[visit_date].tb_status = 'Rx' if status == 'CONFIRMED TB ON TREATMENT'
        #	patient_visits[visit_date].tb_status = 'Rx' if status == 'CURRENTLY IN TREATMENT'

      elsif concept_name.upcase == 'ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT'
        patient_visits[visit_date].reg = 'Unknown' if obs.value_coded == Core::ConceptName.find_by_name("Unknown antiretroviral drug").concept_id
        patient_visits[visit_date].reg = Core::Concept.find_by_concept_id(obs.value_coded).concept_names.typed("SHORT").first.name if !patient_visits[visit_date].reg

      elsif concept_name.upcase == 'DRUG INDUCED'
        symptoms = obs.to_s.split(':').map do |sy|
          sy.sub(concept_name, '').strip.capitalize
        end rescue []
        patient_visits[visit_date].s_eff = symptoms.join("<br/>") unless symptoms.blank?

      elsif concept_name.upcase == 'AMOUNT OF DRUG BROUGHT TO CLINIC'
        drug = Core::Drug.find(obs.order.drug_order.drug_inventory_id) rescue nil
        #tb_medical = MedicationService.tb_medication(drug) unless drug.nil?
        #next if tb_medical == true
        next if drug.blank?
        drug_name = drug.concept.shortname rescue drug.name
        patient_visits[visit_date].pills = [] if patient_visits[visit_date].pills.blank?
        patient_visits[visit_date].pills << [drug_name, obs.value_numeric] rescue []

      elsif concept_name.upcase == 'WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER'
        drug = Core::Drug.find(obs.order.drug_order.drug_inventory_id) rescue nil
        #tb_medical = MedicationService.tb_medication(drug) unless drug.nil?
        #next if tb_medical == true
        next if obs.value_numeric.blank?
        patient_visits[visit_date].adherence = [] if patient_visits[visit_date].adherence.blank?
        patient_visits[visit_date].adherence << [Core::Drug.find(obs.order.drug_order.drug_inventory_id).name, (obs.value_numeric.to_s + '%')]
      elsif concept_name == 'CLINICAL NOTES CONSTRUCT' || concept_name == 'Clinical notes construct'
        patient_visits[visit_date].notes+= '<br/>' + obs.value_text unless patient_visits[visit_date].notes.blank?
        patient_visits[visit_date].notes = obs.value_text if patient_visits[visit_date].notes.blank?
      end


    end

    #patients currents/available states (patients outcome/s)
    program_id = Core::Program.find_by_name('CHRONIC CARE PROGRAM').id

    if encounter_date.blank?
      patient_states = Core::PatientState.find(:all,
                                         :joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
                                         :conditions => ["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND p.patient_id = ?",
                                                         program_id, patient_obj.patient_id], :order => "patient_state_id ASC")
    else
      patient_states = Core::PatientState.find(:all,
                                         :joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
                                         :conditions => ["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND start_date = ? AND p.patient_id =?",
                                                         program_id, encounter_date.to_date, patient_obj.patient_id], :order => "patient_state_id ASC")

      #raise patient_visits[encounter_date].gave.to_yaml

    end

    #=begin
    patient_states.each do |state|
      visit_date = state.start_date.to_date rescue nil
      next if visit_date.blank?
      patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?
      patient_visits[visit_date].outcome = state.program_workflow_state.concept.fullname rescue 'Alive'
      patient_visits[visit_date].date_of_outcome = state.start_date
    end
    #=end

    patient_visits.each do |visit_date, data|
      next if visit_date.blank?
      # patient_visits[visit_date].outcome = hiv_state(patient_obj,visit_date)
      #patient_visits[visit_date].date_of_outcome = visit_date

      status = tb_status(patient_obj, visit_date).upcase rescue nil
      patient_visits[visit_date].tb_status = status
      patient_visits[visit_date].tb_status = 'noSup' if status == 'UNKNOWN'
      patient_visits[visit_date].tb_status = 'noSup' if status == 'TB NOT SUSPECTED'
      patient_visits[visit_date].tb_status = 'sup' if status == 'TB SUSPECTED'
      patient_visits[visit_date].tb_status = 'noRx' if status == 'CONFIRMED TB NOT ON TREATMENT'
      patient_visits[visit_date].tb_status = 'Rx' if status == 'CONFIRMED TB ON TREATMENT'
      patient_visits[visit_date].tb_status = 'Rx' if status == 'CURRENTLY IN TREATMENT'
    end

    unless encounter_date.blank?
      outcome = patient_visits[encounter_date].outcome rescue nil
      if outcome.blank?
        state = Core::PatientState.find(:first,
                                  :joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
                                  :conditions => ["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND p.patient_id = ?",
                                                  program_id, patient_obj.patient_id], :order => "date_enrolled DESC,start_date DESC")

        patient_visits[encounter_date] = Mastercard.new() if patient_visits[encounter_date].blank?
        patient_visits[encounter_date].outcome = state.program_workflow_state.concept.fullname rescue 'Unknown state'
        patient_visits[encounter_date].date_of_outcome = state.start_date rescue nil
      end
    end

    patient_visits
  end

  def lab_results(patient_id, visit_date)
    encounter_type = Core::EncounterType.find_by_name("Lab Results")
    encounter = Core::Encounter.find(:all, :conditions => ["encounter_type = #{encounter_type.encounter_type_id} and patient_id = #{patient_id}
                  AND voided = 0 AND DATE(encounter_datetime) = ?", visit_date.strftime("%Y-%m-%d")])
    obs = Core::Observation.find(:all, :conditions => ["encounter_id = ? AND obs_group_id IS NULL", encounter.first.encounter_id]) rescue []
    result_set = []
    obs.each {|o|
      name = o.to_s.split(':')[0]
      value = Core::Observation.find(:last, :conditions => ["obs_group_id = ?", o.obs_id]).to_s.split(':')
      name = "#{value[0].chars.first}Ch" if name.match(/Cholesterol/i)
      name = "#{value[0].chars.first}BS" if name.match(/Blood Sugar/i)
      name = "SeC" if name.match(/Serum creatinine/i)

      result_set << "#{name} :#{(value[1].strip.to_f / 18).round(0).to_i} mmol/l"
    }
    return result_set
  end

  def mastercard_visit_data(visit)
    return if visit.blank?
    data = {}

    data["bp"] = visit.bp rescue nil
    data["outcome"] = visit.outcome rescue nil
    data["outcome_date"] = "#{visit.date_of_outcome.to_date.strftime('%b %d %Y')}" if visit.date_of_outcome

    if visit.appointment_date
      data["next_appointment"] = "Next: #{visit.appointment_date.strftime('%b %d %Y')}"
    end

    count = 1
    (visit.s_eff.split("<br/>").compact.reject(&:blank?) || []).each do |side_eff|
      data["side_eff#{count}"] = "25",side_eff[0..5]
      count+=1
    end if visit.s_eff

    count = 1
    (visit.gave || []).each do | drug, pills |
      drug = drug.split(";")
      string = "#{drug[0]} (#{pills})"
      if string.length > 26
        line = string[0..25]
        line2 = string[26..-1]
        data["arv_given#{count}"] = "255",line
        data["arv_given#{count+=1}"] = "255","#{line2} ; #{drug[1]} ; #{drug[2]} ; #{drug[3]}"
      else
        data["arv_given#{count}"] = "255","#{string} ; #{drug[1]} ; #{drug[2]} ; #{drug[3]}"
      end
      count+= 1
    end #rescue []

    unless visit.cpt.blank?
      data["arv_given#{count}"] = "255","CPT (#{visit.cpt})" unless visit.cpt == 0
    end #rescue []

    data
  end

  def life_style(patient_id, visit_date)
    concept = Core::ConceptName.find_by_name("You receive helpful advice on important things in your life").concept_id
    obs = Core::Observation.find(:all, :conditions => ["concept_id = ? AND voided = 0 AND person_id = ? AND DATE(obs_datetime) = ?", concept, patient_id, visit_date.strftime('%Y-%m-%d')]) rescue []
    result_set = []
    obs.each {|o|
      result_set << o.to_s.split(':')[1]
    }
    return result_set
  end

  def seen_by(patient,date = Date.today)
    provider = patient.encounters.find_by_date(date).collect{|e| next unless e.name == 'HIV CLINIC CONSULTATION' ; [e.name,e.creator]}.compact
    provider_username = "#{'Seen by: ' + Core::User.find(provider[0].last).username}" unless provider.blank?
    if provider_username.blank?
      clinic_encounters = ["EPILEPSY CLINIC VISIT","DIABETES HYPERTENSION INITIAL VISIT","TREATMENT",'APPOINTMENT']
      encounter_type_ids = Core::EncounterType.find(:all,:conditions =>["name IN (?)",clinic_encounters]).collect{| e | e.id }
      encounter = Core::Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type In (?)",
                                                       patient.id,encounter_type_ids],:order => "encounter_datetime DESC")
      provider_username = "#{'Recorded by: ' + Core::User.find(encounter.creator).username}" rescue nil
    end
    provider_username
  end

  def print_demographics
    #raise params[:user_id]
    print_and_redirect("/patients/patient_demographics_label/#{@patient.id}?user_id=#{params[:user_id]}", "/patients/show?id=#{@patient.id}&user_id=#{params[:user_id]}")
  end

  def patient_demographics_label
    print_string = demographics_label(params[:id])
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def demographics_label(patient_id)
    patient = Core::Patient.find(patient_id)

    demographics = mastercard_demographics(patient)

    office_phone_number = PatientService.get_attribute(patient.person, 'Office phone number')
    home_phone_number = PatientService.get_attribute(patient.person, 'Home phone number')
    cell_phone_number = PatientService.get_attribute(patient.person, 'Cell phone number')

    phone_number = office_phone_number if not office_phone_number.downcase == "not available" and not office_phone_number.downcase == "unknown" rescue nil
    phone_number= home_phone_number if not home_phone_number.downcase == "not available" and not home_phone_number.downcase == "unknown" rescue nil
    phone_number = cell_phone_number if not cell_phone_number.downcase == "not available" and not cell_phone_number.downcase == "unknown" rescue nil

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
    label.draw_text("#{demographics.arv_number}",575,30,0,3,1,1,false)
    label.draw_text("PATIENT DETAILS",25,30,0,3,1,1,false)
    label.draw_text("Name:   #{demographics.name} (#{demographics.sex})",25,60,0,3,1,1,false)
    label.draw_text("DOB:    #{PatientService.birthdate_formatted(patient.person)}",25,90,0,3,1,1,false)
    label.draw_text("Phone: #{phone_number}",25,120,0,3,1,1,false)
    if demographics.address.length > 48
      label.draw_text("Addr:  #{demographics.address[0..47]}",25,150,0,3,1,1,false)
      label.draw_text("    :  #{demographics.address[48..-1]}",25,180,0,3,1,1,false)
      last_line = 180
    else
      label.draw_text("Addr:  #{demographics.address}",25,150,0,3,1,1,false)
      last_line = 150
    end

    if !demographics.guardian.nil?
      if last_line == 180 and demographics.guardian.length < 48
        label.draw_text("Guard: #{demographics.guardian}",25,210,0,3,1,1,false)
        last_line = 210
      elsif last_line == 180 and demographics.guardian.length > 48
        label.draw_text("Guard: #{demographics.guardian[0..47]}",25,210,0,3,1,1,false)
        label.draw_text("     : #{demographics.guardian[48..-1]}",25,240,0,3,1,1,false)
        last_line = 240
      elsif last_line == 150 and demographics.guardian.length > 48
        label.draw_text("Guard: #{demographics.guardian[0..47]}",25,180,0,3,1,1,false)
        label.draw_text("     : #{demographics.guardian[48..-1]}",25,210,0,3,1,1,false)
        last_line = 210
      elsif last_line == 150 and demographics.guardian.length < 48
        label.draw_text("Guard: #{demographics.guardian}",25,180,0,3,1,1,false)
        last_line = 180
      end
    else
      if last_line == 180
        label.draw_text("Guard: None",25,210,0,3,1,1,false)
        last_line = 210
      elsif last_line == 180
        label.draw_text("Guard: None}",25,210,0,3,1,1,false)
        last_line = 240
      elsif last_line == 150
        label.draw_text("Guard: None",25,180,0,3,1,1,false)
        last_line = 210
      elsif last_line == 150
        label.draw_text("Guard: None",25,180,0,3,1,1,false)
        last_line = 180
      end
    end

    label.draw_text("TI:    #{demographics.transfer_in ||= 'No'}",25,last_line+=30,0,3,1,1,false)

    return "#{label.print(1)}"
  end

  def mastercard_demographics(patient_obj)

    #patient_bean = PatientService.get_patient(patient_obj.person)
    visits = Mastercard.new()
    visits.zone = get_global_property_value("facility.zone.name")# rescue "Unknown"
    visits.clinic = get_global_property_value("facility.name")# rescue "Unknown"
    visits.district = get_global_property_value("facility.district")# rescue "Unknown"
    visits.patient_id = patient_obj.id
    # visits.arv_number = patient_obj.arv_number# rescue ""
    visits.address = patient_obj.address
    visits.national_id = patient_obj.national_id
    visits.name = patient_obj.name # rescue nil
    # raise visits.name.to_yaml
    visits.sex = patient_obj.gender
    visits.age = patient_obj.age
    visits.birth_date = patient_obj.person.birthdate rescue patient_obj.person.birthdate_estimated rescue nil
    visits.occupation = Vitals.occupation(patient_obj).value rescue "Not specified"
    visits.landmark = patient_obj.person.addresses.first.address1 rescue ""
    visits.init_wt = Vitals.get_patient_attribute_value(patient_obj, "initial_weight")
    visits.init_ht = Vitals.get_patient_attribute_value(patient_obj, "initial_height")
    visits.agrees_to_followup = patient_obj.person.observations.recent(1).question("Agrees to followup").all rescue nil
    visits.agrees_to_followup = visits.agrees_to_followup.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_date = patient_obj.person.observations.recent(1).question("Confirmatory HIV test date").all rescue nil
    visits.hiv_test_date = visits.hiv_test_date.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_location = patient_obj.person.observations.recent(1).question("Confirmatory HIV test location").all rescue nil
    location_name = Location.find_by_location_id(visits.hiv_test_location.to_s.split(':')[1].strip).name rescue nil
    visits.hiv_test_location = location_name rescue nil
    visits.appointment_date = current_vitals(patient_obj,"APPOINTMENT DATE").to_s
    visits.history_asthma = current_vitals(patient_obj,"Has the family a history of asthma?").to_s.split(':')[1].match(/yes/i) rescue nil
    ! visits.history_asthma.blank? ? visits.history_asthma = "Y" : visits.history_asthma = "N"
    visits.guardian = Vitals.guardian(patient_obj) rescue nil
    visits.reason_for_art_eligibility = PatientService.reason_for_art_eligibility(patient_obj) rescue nil
    visits.transfer_in = current_vitals(patient_obj, "TYPE OF PATIENT").to_s.split(":")[1].match(/transfer in/i) rescue nil #pb: bug-2677 Made this to use the newly created patient model method 'transfer_in?'
    ! visits.transfer_in.blank? ? visits.transfer_in = 'NO' : visits.transfer_in = 'YES'

    transferred_out_details = Core::Observation.find(:last, :conditions =>["concept_id = ? and person_id = ?", Core::ConceptName.find_by_name("TRANSFER OUT TO").concept_id,patient_obj.id]) rescue ""

    visits.transferred_out_to = transferred_out_details.value_text if transferred_out_details
    visits.transferred_out_date = transferred_out_details.obs_datetime if transferred_out_details

    visits.art_start_date = PatientService.patient_art_start_date(patient_obj.id).strftime("%d-%B-%Y") rescue nil

    visits.transfer_in_date = patient_obj.person.observations.recent(1).question("TYPE OF PATIENT").all.collect{|o|
      o.obs_datetime if o.answer_string.match(/transfer in/i)}.last rescue nil

    regimens = {}
    regimen_types = ['FIRST LINE ANTIRETROVIRAL REGIMEN','ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN','SECOND LINE ANTIRETROVIRAL REGIMEN']
    regimen_types.map do | regimen |
      concept_member_ids = Core::ConceptName.find_by_name(regimen).concept.concept_members.collect{|c|c.concept_id}
      case regimen
        when 'FIRST LINE ANTIRETROVIRAL REGIMEN'
          regimens[regimen] = concept_member_ids
        when 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN'
          regimens[regimen] = concept_member_ids
        when 'SECOND LINE ANTIRETROVIRAL REGIMEN'
          regimens[regimen] = concept_member_ids
      end
    end

    first_treatment_encounters = []
    encounter_type = Core::EncounterType.find_by_name('DISPENSING').id
    amount_dispensed_concept_id = Core::ConceptName.find_by_name('Amount dispensed').concept_id
    regimens.map do | regimen_type , ids |
      encounter = Core::Encounter.find(:first,
                                 :joins => "INNER JOIN obs ON encounter.encounter_id = obs.encounter_id",
                                 :conditions =>["encounter_type=? AND encounter.patient_id = ? AND concept_id = ?
                                 AND encounter.voided = 0",encounter_type , patient_obj.id , amount_dispensed_concept_id ],
                                 :order =>"encounter_datetime")
      first_treatment_encounters << encounter unless encounter.blank?
    end

    visits.first_line_drugs = []
    visits.alt_first_line_drugs = []
    visits.second_line_drugs = []

    first_treatment_encounters.map do | treatment_encounter |
      treatment_encounter.observations.map{|obs|
        next if not obs.concept_id == amount_dispensed_concept_id
        drug = Core::Drug.find(obs.value_drug) if obs.value_numeric > 0
        next if obs.value_numeric <= 0
        drug_concept_id = drug.concept.concept_id
        regimens.map do | regimen_type , concept_ids |
          if regimen_type == 'FIRST LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_first_line_regimen =  PatientService.date_antiretrovirals_started(patient_obj) #treatment_encounter.encounter_datetime.to_date
            visits.first_line_drugs << drug.concept.shortname
            visits.first_line_drugs = visits.first_line_drugs.uniq rescue []
          elsif regimen_type == 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_first_alt_line_regimen = PatientService.date_antiretrovirals_started(patient_obj) #treatment_encounter.encounter_datetime.to_date
            visits.alt_first_line_drugs << drug.concept.shortname
            visits.alt_first_line_drugs = visits.alt_first_line_drugs.uniq rescue []
          elsif regimen_type == 'SECOND LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_second_line_regimen = treatment_encounter.encounter_datetime.to_date
            visits.second_line_drugs << drug.concept.shortname
            visits.second_line_drugs = visits.second_line_drugs.uniq rescue []
          end
        end
      }.compact
    end

    ans = ["Extrapulmonary tuberculosis (EPTB)","Pulmonary tuberculosis within the last 2 years","Pulmonary tuberculosis (current)","Kaposis sarcoma","Pulmonary tuberculosis"]
    staging_ans = patient_obj.person.observations.recent(1).question("WHO STAGES CRITERIA PRESENT").all
    if staging_ans.blank?
      staging_ans = patient_obj.person.observations.recent(1).question("WHO STG CRIT").all
    end
    #raise current_vitals(patient_obj, "cardiovascular complications present").to_yaml

    visits.diagnosis_asthma = current_encounter(patient_obj, "ASTHMA MEASURE", "ASTHMA").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.diagnosis_asthma.blank? ? visits.diagnosis_asthma = "Y" : visits.diagnosis_asthma = "N"

    visits.diagnosis_stroke = current_encounter(patient_obj, "GENERAL HEALTH", "CHRONIC DISEASE").to_s.match(/Acute cerebrovascular attack/i) rescue nil
    ! visits.diagnosis_stroke.blank? ? visits.diagnosis_stroke = "Y" : visits.diagnosis_stroke = "N"

    visits.smoking = current_vitals(patient_obj, "current smoker").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.smoking.blank? ? visits.smoking = "Y" : visits.smoking = "N"

    visits.alcohol = current_vitals(patient_obj, "Does the patient drink alcohol?").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.alcohol.blank? ? visits.alcohol = 'Y' : visits.alcohol = 'N'

    visits.dm = current_vitals(patient_obj, "diabetes family history").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.dm.blank? ? visits.dm = "Y" : visits.dm = "N"

    visits.htn = current_vitals(patient_obj, "Does the family have a history of hypertension?").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.htn.blank? ? visits.htn = "Y" : visits.htn = "N"

    visits.tb_within_last_two_yrs = current_vitals(patient_obj, "tb in previous two years").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.tb_within_last_two_yrs.blank? ? visits.tb_within_last_two_yrs = "Y" : visits.tb_within_last_two_yrs = "N"

    visits.asthma = current_encounter(patient_obj, "MEDICAL HISTORY", "asthma").to_s.split(":")[1].asthma.match(/yes/i) rescue nil
    visits.asthma == "yes" ? visits.asthma = "Y" : visits.asthma = "N"

    visits.stroke = current_vitals(patient_obj, "ever had a stroke").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.stroke.blank? ? visits.stroke = "Y" : visits.stroke = "N"

    visits.hiv_status = current_encounter(patient_obj, "UPDATE HIV STATUS", "HIV STATUS").to_s.split(":")[1].match(/positive/i) rescue nil
    ! visits.hiv_status.blank? ? visits.hiv_status = "R" : visits.hiv_status = "NR"

    visits.art_status = current_vitals(patient_obj, "on art").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.art_status.blank? ? visits.art_status = "Y" : visits.art_status = "N"

    visits.oedema = current_encounter(patient_obj, "COMPLICATIONS", "oedema") rescue []
    ! visits.oedema.blank? ? visits.oedema = "Y Date: #{visits.oedema.to_s.split(":")[1]}" : visits.oedema = "N"

    visits.cardiac = current_encounter(patient_obj, "COMPLICATIONS", "Cardiac") rescue []
    ! visits.cardiac.blank? ? visits.cardiac = "Y Date: #{visits.cardiac.to_s.split(":")[1]}" : visits.cardiac = "N"

    visits.mi = current_encounter(patient_obj, "COMPLICATIONS", "myocardial injactia") rescue []
    ! visits.mi.blank? ? visits.mi = "Y Date: #{visits.mi.to_s.split(":")[1]}" : visits.mi = "N"

    visits.funduscopy = current_encounter(patient_obj, "COMPLICATIONS", "fundus") rescue []
    ! visits.funduscopy.blank? ? visits.funduscopy = "Y Date: #{visits.funduscopy.to_s.split(":")[1]}" : visits.funduscopy = "N"

    visits.creatinine = current_encounter(patient_obj, "COMPLICATIONS", "Creatinine") rescue []
    ! visits.creatinine.blank? ? visits.creatinine = "Y Date: #{visits.creatinine.to_s.split(":")[1]}" : visits.creatinine = "N"

    visits.comp_stroke = current_encounter(patient_obj, "COMPLICATIONS", "stroke") rescue []
    ! visits.comp_stroke.blank? ? visits.creatinine = "Y" : visits.comp_stroke = "N"

    chronic_diseases = current_encounter(patient_obj, "GENERAL HEALTH", "CHRONIC DISEASE").to_s.match(/Chronic disease:   TIA/i) rescue nil
    ! chronic_diseases.blank? ? visits.tia = "Y" : visits.tia = "N"

    visits.amputation = current_encounter(patient_obj, "COMPLICATIONS", "COMPLICATIONS").to_s.match(/Complications:  Amputation/i) rescue nil
    ! visits.amputation.blank? ? visits.amputation = "Y" : visits.amputation = "N"

    #raise Vitals.current_encounter(patient_obj, "COMPLICATIONS", "COMPLICATIONS").to_s.to_yaml
    visits.neuropathy = current_encounter(patient_obj, "COMPLICATIONS", "COMPLICATIONS").to_s.match(/Complications:   Peripheral nueropathy/i) rescue nil
    ! visits.neuropathy.blank? ? visits.neuropathy = "Y" : visits.neuropathy = "N"

    visits.foot_ulcers = current_encounter(patient_obj, "COMPLICATIONS", "COMPLICATIONS").to_s.match(/Complications:   Foot ulcers/i) rescue nil
    ! visits.foot_ulcers.blank? ? visits.foot_ulcers = "Y" : visits.foot_ulcers = "N"

    visits.impotence = current_encounter(patient_obj, "COMPLICATIONS", "COMPLICATIONS").to_s.match(/Complications:  Impotence/i) rescue nil
    ! visits.impotence.blank? ? visits.impotence = "Y" : visits.impotence = "N"

    visits.comp_other = current_encounter(patient_obj, "COMPLICATIONS", "COMPLICATIONS").to_s.match(/Complications:   Others/i) rescue nil
    ! visits.comp_other.blank? ? visits.comp_other = "Y" : visits.comp_other = "N"

    visits.diagnosis_dm = current_vitals(patient_obj, "Patient has Diabetes").to_s.match(/yes/i) rescue nil
    ! visits.diagnosis_dm.blank? ? visits.diagnosis_dm = "Y" : visits.diagnosis_dm = "N"

    visits.pork = current_vitals(patient_obj, "Food package provided").to_s.match(/Eats pork/i) rescue nil
    ! visits.pork.blank? ? visits.pork = "Y" : visits.pork = "N"

    visits.epilepsy = current_vitals(patient_obj, "Epilepsy").to_s.match(/yes/i) rescue nil
    ! visits.epilepsy.blank? ? visits.epilepsy = "Y" : visits.epilepsy = "N"

    visits.psychosis = current_vitals(patient_obj, "psychosis").to_s.match(/yes/i) rescue nil
    ! visits.psychosis.blank? ? visits.psychosis = "Y" : visits.psychosis = "N"

    visits.hyperactivity = current_vitals(patient_obj, "hyperactivity").to_s.match(/yes/i) rescue nil
    ! visits.hyperactivity.blank? ? visits.hyperactivity = "Y" : visits.hyperactivity = "N"

    visits.drug_related = current_encounter(patient_obj, "EPILEPSY CLINIC VISIT", "Cause of Seizure").to_s.match(/alcohol withdrawal/i) rescue nil
    ! visits.drug_related .blank? ? visits.drug_related  = "Y" : visits.drug_related  = "N"

    visits.known_seizure = current_vitals(patient_obj, "Seizures known epileptic").to_s.match(/yes/i) rescue nil
    ! visits.known_seizure.blank? ? visits.known_seizure = "Y" : visits.known_seizure = "N"

    visits.seizure_history = current_vitals(patient_obj, "Seizures").to_s.match(/yes/i) rescue nil
    ! visits.seizure_history.blank? ? visits.seizure_history = "Y" : visits.seizure_history = "N"

    visits.cysticercosis = current_vitals(patient_obj, "Cysticercosis").to_s.match(/yes/i) rescue nil
    ! visits.cysticercosis.blank? ? visits.cysticercosis = "Y" : visits.cysticercosis = "N"

    visits.cerebral_maralia = current_vitals(patient_obj, "Cysticercosis").to_s.match(/yes/i) rescue nil
    ! visits.cerebral_maralia.blank? ? visits.cerebral_maralia = "Y" : visits.cerebral_maralia = "N"

    visits.meningitis = current_vitals(patient_obj, "Meningitis").to_s.match(/yes/i) rescue nil
    ! visits.meningitis.blank? ? visits.meningitis = "Y" : visits.meningitis = "N"

    visits.burns = current_vitals(patient_obj, "Burns").to_s.match(/yes/i) rescue nil
    ! visits.burns.blank? ? visits.burns = "Y" : visits.burns = "N"


    visits.injuries = current_encounter(patient_obj, "EPILEPSY CLINIC VISIT", "Head injury").to_s.match(/yes/i) rescue nil
    # visits.injuries = current_vitals(patient_obj, "Head injury").to_s.match(/yes/i) rescue nil
    ! visits.injuries.blank? ? visits.injuries = "Y" : visits.injuries = "N"

    visits.head_trauma = current_encounter(patient_obj, "MEDICAL HISTORY", "Head injury").to_s.match(/yes/i) rescue nil
    # visits.injuries = current_vitals(patient_obj, "Head injury").to_s.match(/yes/i) rescue nil
    ! visits.head_trauma.blank? ? visits.head_trauma = "Y" : visits.head_trauma = "N"

    visits.atomic = current_vitals(patient_obj, "generalised").to_s.match(/Atomic/i) rescue nil
    ! visits.atomic.blank? ? visits.atomic = "Y" : visits.atomic = "N"

    visits.tonic = current_vitals(patient_obj, "generalised").to_s.match(/ Tonic/i) rescue nil
    ! visits.tonic.blank? ? visits.tonic = "Y" : visits.tonic = "N"

    visits.clonic = current_vitals(patient_obj, "generalised").to_s.match(/ Clonic/i) rescue nil
    ! visits.clonic.blank? ? visits.clonic = "Y" : visits.clonic = "N"

    visits.myclonic = current_vitals(patient_obj, "generalised").to_s.match(/ Myclonic/i) rescue nil
    ! visits.myclonic.blank? ? visits.myclonic = "Y" : visits.myclonic = "N"

    visits.absence = current_vitals(patient_obj, "generalised").to_s.match(/ Absence/i) rescue nil
    ! visits.absence.blank? ? visits.absence = "Y" : visits.absence = "N"

    visits.tonic_clonic = current_vitals(patient_obj, "generalised").to_s.match(/ Tonic Clonic/i) rescue nil
    ! visits.tonic_clonic.blank? ? visits.tonic_clonic = "Y" : visits.tonic_clonic = "N"

    visits.complex = current_vitals(patient_obj, "Focal seizure").to_s.match(/ Complex/i) rescue nil
    ! visits.complex.blank? ? visits.complex = "Y" : visits.complex = "N"

    visits.simplex = current_vitals(patient_obj, "Focal seizure").to_s.match(/ Simplex/i) rescue nil
    ! visits.simplex.blank? ? visits.simplex = "Y" : visits.simplex = "N"

    visits.unclassified = "N"
    if visits.atomic == "N" and visits.tonic == "N" and visits.clonic == "N" and visits.myclonic == "N" and visits.absence == "N" and visits.tonic_clonic == "N" and visits.complex == "N" and visits.simplex == "N"
      visits.unclassified = "Y"
    end

    visits.status_epileptus = current_vitals(patient_obj, "Confirm diagnosis of epilepsy").to_s.match(/yes/i) rescue nil
    ! visits.status_epileptus.blank? ? visits.status_epileptus = "Y" : visits.status_epileptus = "N"

    visits.mental_illness = current_vitals(patient_obj, "Mental Disorders").to_s.match(/yes/i) rescue nil
    ! visits.mental_illness.blank? ? visits.mental_illness = "Y" : visits.mental_illness = "N"

    visits.diagnosis_htn = current_vitals(patient_obj, "cardiovascular system diagnosis").to_s.match(/Hypertension /i) rescue nil

    ! visits.diagnosis_htn.blank? ? visits.diagnosis_htn = "Y" : visits.diagnosis_htn = "N"

    visits.diagnosis_dm_htn = "N"
    visits.diagnosis_dm_htn = "Y" if visits.diagnosis_htn = "Y" and visits.diagnosis_dm = "Y"

    hiv_staging = Core::Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
                                                            Core::EncounterType.find_by_name("HIV Staging").id,patient_obj.id])

    visits.who_clinical_conditions = ""
    (hiv_staging.observations).collect do |obs|
      if CoreService.get_global_property_value('use.extended.staging.questions').to_s == 'true'
        name = obs.to_s.split(':')[0].strip rescue nil
        ans = obs.to_s.split(':')[1].strip rescue nil
        next unless ans.upcase == 'YES'
        visits.who_clinical_conditions = visits.who_clinical_conditions + (name) + "; "
      else
        name = obs.to_s.split(':')[0].strip rescue nil
        next unless name == 'WHO STAGES CRITERIA PRESENT'
        condition = obs.to_s.split(':')[1].strip.humanize rescue nil
        visits.who_clinical_conditions = visits.who_clinical_conditions + (condition) + "; "
      end
    end rescue []

    visits.cd4_count_date = nil ; visits.cd4_count = nil ; visits.pregnant = 'N/A'

    (hiv_staging.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name.downcase
        when 'cd4 count datetime'
          visits.cd4_count_date = obs.value_datetime.to_date
        when 'cd4 count'
          visits.cd4_count = "#{obs.value_modifier}#{obs.value_numeric.to_i}"
        when 'is patient pregnant?'
          visits.pregnant = obs.to_s.split(':')[1] rescue nil
        when 'lymphocyte count'
          visits.tlc = obs.answer_string
        when 'lymphocyte count date'
          visits.tlc_date = obs.value_datetime.to_date
      end
    end rescue []

    visits.tb_status_at_initiation = (!visits.tb_status.nil? ? "Curr" :
        (!visits.tb_within_last_two_yrs.nil? ? (visits.tb_within_last_two_yrs.upcase == "YES" ?
            "Last 2yrs" : "Never/ >2yrs") : "Never/ >2yrs"))

    hiv_clinic_registration = Core::Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
                                                                        Core::EncounterType.find_by_name("HIV CLINIC REGISTRATION").id,patient_obj.id])

    (hiv_clinic_registration.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
        when 'Ever received ART?'
          visits.ever_received_art = obs.to_s.split(':')[1].strip rescue nil
        when 'Last ART drugs taken'
          visits.last_art_drugs_taken = obs.to_s.split(':')[1].strip rescue nil
        when 'Date ART last taken'
          visits.last_art_drugs_date_taken = obs.value_datetime.to_date rescue nil
        when 'Confirmatory HIV test location'
          visits.first_positive_hiv_test_site = obs.to_s.split(':')[1].strip rescue nil
        when 'ART number at previous location'
          visits.first_positive_hiv_test_arv_number = obs.to_s.split(':')[1].strip rescue nil
        when 'Confirmatory HIV test type'
          visits.first_positive_hiv_test_type = obs.to_s.split(':')[1].strip rescue nil
        when 'Confirmatory HIV test date'
          visits.first_positive_hiv_test_date = obs.value_datetime.to_date rescue nil
      end
    end rescue []

    visits
  end

  def current_vitals(patient, vital_sign, session_date = Date.today)
    concept = Core::ConceptName.find_by_name("#{vital_sign}").concept_id
    Core::Observation.find_by_sql("SELECT * from obs where concept_id = #{concept} AND person_id = #{patient.id}
                    AND DATE(obs_datetime) <= '#{session_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first #rescue nil
  end

  protected

  def find_patient

    @patient = Core::Patient.find(params[:id] || params[:patient_id]) rescue nil


  end

end
