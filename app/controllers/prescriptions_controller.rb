class PrescriptionsController < ApplicationController
# Is this used?
  def index
    @user = User.find(params[:user_id]) rescue nil
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @orders = @patient.orders.prescriptions.current.all rescue []
    @history = @patient.orders.prescriptions.historical.all rescue []
    #redirect_to "/prescriptions/new?patient_id=#{params[:patient_id] || session[:patient_id]}&user_id=#{@user.id}" and return if @orders.blank?
    render :template => 'prescriptions/index', :layout => 'menu'
  end

  def new
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @patient_diagnoses = current_diagnoses(@patient.person.id)
    @current_weight = Vitals.current_vitals(@patient, "weight (kg)") rescue nil
    @current_height = Vitals.current_vitals(@patient, "height (cm)") rescue nil
  end

  def void
    @user = User.find(params[:user_id]) rescue nil
    @order = Order.find(params[:order_id])
    @order.void
    flash.now[:notice] = "Order was successfully voided"
    if !params[:source].blank? && params[:source].to_s == 'advanced'
      redirect_to "/prescriptions/advanced_prescription?patient_id=#{params[:patient_id]}&user_id=#{@user.id}" and return
    else
      redirect_to :action => "index", :patient_id => params[:patient_id], :user_id => @user.id and return
    end
  end

  def create
    unless session[:datetime].blank?
      session[:datetime] = nil if session[:datetime].to_date == Date.today
    end
    @suggestions = params[:suggestion] || ['New Prescription']
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    if params[:location].blank?
      session_date = session[:datetime] || params[:encounter_datetime] || Time.now()
    else
      session_date = params[:encounter_datetime] #Use encounter_datetime passed during import
    end
    # set current location via params if given
    Location.current_location = Location.find(params[:location]) if params[:location]

    if params[:filter] and !params[:filter][:provider].blank?
      user_person_id = User.find_by_username(params[:filter][:provider]).person_id
      #elsif params[:location] # migration
      # user_person_id = params[:provider_id]
    else
      user_person_id = User.find_by_user_id(params[:user_id]).person_id
    end

    if user_person_id.blank?
      user_person_id = User.find(1).person_id rescue []
    end

    @encounter = current_prescription_encounter(@patient, session_date, user_person_id)

    @program = Program.find_by_concept_id(ConceptName.find_by_name('CHRONIC CARE PROGRAM').concept_id) rescue nil

    if !@program.nil?

      @program_encounter = ProgramEncounter.find_by_program_id(@program.id,
                                                               :conditions => ["patient_id = ? AND DATE(date_time) = ?",
                                                                               @patient.id, @encounter.encounter_datetime.to_date.strftime("%Y-%m-%d")])

      if @program_encounter.blank?

        @program_encounter = ProgramEncounter.create(
            :patient_id => @patient.id,
            :date_time => @encounter.encounter_datetime.to_date,
            :program_id => @program.id
        )

      end

      ProgramEncounterDetail.create(
          :encounter_id => @encounter.id.to_i,
          :program_encounter_id => @program_encounter.id,
          :program_id => @program.id
      )

      @current = PatientProgram.find_by_program_id(@program.id,
                                                   :conditions => ["patient_id = ? AND COALESCE(date_completed, '') = ''", @patient.id])

    end


    @diagnosis = Observation.find(params[:diagnosis]) rescue nil

    @suggestions.each do |suggestion|
      unless (suggestion.blank? || suggestion == '0' || suggestion == 'New Prescription')
        @order = DrugOrder.find(suggestion)
        DrugOrder.clone_order(@encounter, @patient, @diagnosis, @order)
      else

        @formulation = (params[:formulation] || params[:prescription][0][:formulation] || '').upcase
        @drug = Drug.find_by_name(@formulation) rescue nil
        unless @drug
          flash[:notice] = "No matching drugs found for formulation #{@formulation}"
          render :new
          return
        end

        prescriptions = params[:prescription][0] rescue params
        #raise params.to_yaml
        start_date = session_date

        auto_expire_date = session_date.to_date + prescriptions[:duration].to_i.days
        #raise @drug.units.to_yaml
        prn = prescriptions[:prn].to_i
        if prescriptions[:type_of_prescription] == "variable"
          DrugOrder.write_order(@encounter,
                                @patient,
                                @diagnosis,
                                @drug,
                                start_date,
                                auto_expire_date,
                                [prescriptions[:morning_dose],
                                 prescriptions[:afternoon_dose],
                                 prescriptions[:evening_dose],
                                 prescriptions[:night_dose]],
                                'VARIABLE',
                                prn)
        else
          DrugOrder.write_order(@encounter,
                                @patient,
                                @diagnosis,
                                @drug,
                                start_date,
                                auto_expire_date,
                                prescriptions[:dose_strength],
                                prescriptions[:frequency],
                                prn,
                                "",
                                3)
        end
      end
    end

    # print_prescribed = CoreService.get_global_property_value('prescription.print') rescue false

    #if print_prescribed != true
    #      print_and_redirect("/patients/prescription_print/#{params[:patient_id]}?user_id=#{params[:user_id]}","/patients/treatment_dashboard/#{@patient.id}?user_id=#{params[:user_id]}")
    #else
    redirect_to  "/patients/treatment_dashboard/#{@patient.id}?user_id=#{params[:user_id]}" and return
    #end

  end

  def current_prescription_encounter(patient, date = Time.now(), provider = user_person_id)
    type = EncounterType.find_by_name("TREATMENT")
    encounter = patient.encounters.find(:first,:conditions =>["DATE(encounter_datetime) = ? AND encounter_type = ?",date.to_date,type.id])
    encounter ||= patient.encounters.create(:encounter_type => type.id,:encounter_datetime => date, :provider_id => provider)
  end

  def prescription_print
    @patient = Patient.find(params[:patient_id])
    print_and_redirect("/patients/prescription_print/#{params[:patient_id]}?user_id=#{params[:user_id]}","/patients/treatment_dashboard/#{@patient.id}?user_id=#{params[:user_id]}")
  end

  def auto
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    # Find the next diagnosis that doesn't have a corresponding order
    @diagnoses = PatientService.current_diagnoses(@patient.person.id)
    @prescriptions = @patient.orders.current.prescriptions.all.map(&:obs_id).uniq
    @diagnoses = @diagnoses.reject {|diag| @prescriptions.include?(diag.obs_id) }
    if @diagnoses.empty?
      redirect_to "/prescriptions/new?patient_id=#{@patient.id}"
    else
      redirect_to "/prescriptions/new?patient_id=#{@patient.id}&diagnosis=#{@diagnoses.first.obs_id}&auto=#{@diagnoses.length == 1 ? 0 : 1}"
    end
  end

  # Look up the set of matching generic drugs based on the concepts. We
  # limit the list to only the list of drugs that are actually in the
  # drug list so we don't pick something we don't have.
  def generics
    search_string = (params[:search_string] || '').upcase
    filter_list = params[:filter_list].split(/, */) rescue []
    @drug_concepts = ConceptName.find(:all,
                                      :select => "concept_name.name",
                                      :joins => "INNER JOIN drug ON drug.concept_id = concept_name.concept_id AND drug.retired = 0",
                                      :conditions => ["concept_name.name LIKE ?", '%' + search_string + '%'],:group => 'drug.concept_id')
    render :text => "<li>" + @drug_concepts.map{|drug_concept| drug_concept.name }.uniq.join("</li><li>") + "</li>"
  end

  # Look up all of the matching drugs for the given generic drugs
  def formulations
    @generic = (params[:generic] || '')
    @concept_ids = ConceptName.find_all_by_name(@generic).map{|c| c.concept_id}
    render :text => "" and return if @concept_ids.blank?
    search_string = (params[:search_string] || '').upcase
    @drugs = Drug.find(:all,
                       :select => "name",
                       :conditions => ["concept_id IN (?) AND name LIKE ?", @concept_ids, '%' + search_string + '%'])
    render :text => "<li>" + @drugs.map{|drug| drug.name }.join("</li><li>") + "</li>"
  end

  # Look up likely durations for the drug
  def durations
    @formulation = (params[:formulation] || '').upcase
    drug = Drug.find_by_name(@formulation) rescue nil
    render :text => "No matching drugs found for #{params[:formulation]}" and return unless drug

    # Grab the 10 most popular durations for this drug
    amounts = []
    orders = DrugOrder.find(:all,
                            :select => 'DATEDIFF(orders.auto_expire_date, orders.start_date) as duration_days',
                            :joins => 'LEFT JOIN orders ON orders.order_id = drug_order.order_id AND orders.voided = 0',
                            :limit => 10,
                            :group => 'drug_inventory_id, DATEDIFF(orders.auto_expire_date, orders.start_date)',
                            :order => 'count(*)',
                            :conditions => {:drug_inventory_id => drug.id})

    orders.each {|order|
      amounts << "#{order.duration_days.to_f}" unless order.duration_days.blank?
    }
    amounts = amounts.flatten.compact.uniq
    render :text => "<li>" + amounts.join("</li><li>") + "</li>"
  end

  # Look up likely dose_strength for the drug
  def dosages
    @formulation = (params[:formulation] || '')
    drug = Drug.find_by_name(@formulation) rescue nil
    render :text => "No matching drugs found for #{params[:formulation]}" and return unless drug

    @frequency = (params[:frequency] || '')

    # Grab the 10 most popular dosages for this drug
    amounts = []
    amounts << "#{drug.dose_strength}" if drug.dose_strength
    orders = DrugOrder.find(:all,
                            :limit => 10,
                            :group => 'drug_inventory_id, dose',
                            :order => 'count(*)',
                            :conditions => {:drug_inventory_id => drug.id, :frequency => @frequency})
    orders.each {|order|
      amounts << "#{order.dose}"
    }
    amounts = amounts.flatten.compact.uniq
    render :text => "<li>" + amounts.join("</li><li>") + "</li>"
  end

  # Look up the units for the first substance in the drug, ideally we should re-activate the units on drug for aggregate units
  def units
    @formulation = (params[:formulation] || '').upcase
    drug = Drug.find_by_name(@formulation) rescue nil
    render :text => "per dose" and return unless drug && !drug.units.blank?
    render :text => drug.units
  end

  def suggested
    @diagnosis = Observation.find(params[:diagnosis]) rescue nil
    @options = []
    render :layout => false and return unless @diagnosis && @diagnosis.value_coded
    @orders = DrugOrder.find_common_orders(@diagnosis.value_coded)
    @options = @orders.map{|o| [o.order_id, o.script] } + @options
    render :layout => false
  end

  # Look up all of the matching drugs for the given drug name
  def name
    search_string = (params[:search_string] || '').upcase
    @drugs = Drug.find(:all,
                       :select => "name",
                       :conditions => ["name LIKE ?", '%' + search_string + '%'])
    render :text => "<li>" + @drugs.map{|drug| drug.name }.join("</li><li>") + "</li>"
  end

  def generic_advanced_prescription

    @user = params[:user_id]
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue []
    @generics = MedicationService.generic

    @frequencies = fully_specified_frequencies

    @formulations = {}
    @combinations = {}
    @generics.each { | generic |
      drugs = Drug.find(:all,	:conditions => ["concept_id = ?", generic[1]])
      drug_formulations = {}
      drugs.each { | drug |
        drug_formulations[drug.name] = [drug.dose_strength, drug.units]
      }
      @formulations[generic[1]] = drug_formulations
    }
    @prn = CoreService.get_global_property_value('show.prn').to_s.downcase rescue "true"

    @diagnosis = @patient.current_diagnoses["DIAGNOSIS"] rescue []
    render :layout => 'application', :template => 'prescriptions/give_drugs'
  end


  def create_advanced_prescription
    @user = params[:user_id]
    @patient    = Patient.find(params[:encounter][:patient_id]  || session[:patient_id]) rescue nil
    @program = Program.find_by_concept_id(ConceptName.find_by_name("chronic care program").concept_id)
    session_date = session[:datetime].to_date rescue Date.today
    type = EncounterType.find_by_name("TREATMENT") rescue nil
    encounter = @patient.encounters.current.find_by_encounter_type(type.id)
    encounter ||= @patient.encounters.create(:encounter_type => type.id, :provider_id => @user, :creator => @user)
    @program_encounter = ProgramEncounter.find_by_program_id(@program.id,
                                                             :conditions => ["patient_id = ? AND DATE(date_time) = ?",
                                                                             @patient.id, session_date.strftime("%Y-%m-%d")])

    if @program_encounter.blank?

      @program_encounter = ProgramEncounter.create(
          :patient_id => @patient.id,
          :date_time => session_date,
          :program_id => @program.id
      )

    end

    ProgramEncounterDetail.create(
        :encounter_id => encounter.id.to_i,
        :program_encounter_id => @program_encounter.id,
        :program_id => @program.id
    )



    #encounter  = MedicationService.current_treatment_encounter(@patient, @user)

    if params[:prescription].blank?
      next if params[:formulation].blank?
      formulation = (params[:formulation] || '').upcase
      drug = Drug.find_by_name(formulation) rescue nil
      unless drug
        flash[:notice] = "No matching drugs found for formulation #{params[:formulation]}"
        render :new
        return
      end
      #start_date = session[:datetime].to_date rescue Time.now
      auto_expire_date = session_date.to_date + params[:duration].to_i.days
      prn = params[:prn].to_i

      if prescription[:type_of_prescription] == "variable"
        DrugOrder.write_order(encounter, @patient, nil, drug, start_date, auto_expire_date, [prescription[:morning_dose],
                                                                                             prescription[:afternoon_dose], prescription[:evening_dose], prescription[:night_dose]],
                              prescription[:type_of_prescription], prn)
      else
        DrugOrder.write_order(encounter, @patient, nil, drug, start_date, auto_expire_date, prescription[:dose_strength],
                              prescription[:frequency], prn)
      end
    else
      (params[:prescription] || []).each{ | prescription |
        prescription[:encounter_id]  = encounter.encounter_id
        prescription[:obs_datetime]  = encounter.encounter_datetime || (session[:datetime] ||  Time.now())
        prescription[:person_id]     = encounter.patient_id

        formulation = (prescription[:formulation] || '').upcase

        drug = Drug.find_by_name(formulation) rescue nil

        unless drug
          flash[:notice] = "No matching drugs found for formulation #{prescription[:formulation]}"
          render :new
          return
        end

        start_date = session[:datetime].to_date rescue nil
        start_date = Time.now() if start_date.blank?

        auto_expire_date = start_date + prescription[:duration].to_i.days
        prn = prescription[:prn]


        if prescription[:type_of_prescription] == "variable"
          DrugOrder.write_order(encounter, @patient, nil, drug, start_date, auto_expire_date, [prescription[:morning_dose],
                                                                                               prescription[:afternoon_dose], prescription[:evening_dose], prescription[:night_dose]],
                                prescription[:type_of_prescription], prn)
        else
          DrugOrder.write_order(encounter, @patient, nil, drug, start_date, auto_expire_date, prescription[:dose_strength],
                                prescription[:frequency], prn)
        end

      }
    end

    print_prescribed = CoreService.get_global_property_value('prescription.print') rescue false

    if print_prescribed == true
      print_and_redirect("/patients/prescription_print/#{params[:patient_id]}?user_id=#{params[:user_id]}","/patients/treatment_dashboard/#{@patient.id}?user_id=#{params[:user_id]}")
    else
      redirect_to  "/patients/treatment_dashboard/#{@patient.id}?user_id=#{params[:user_id]}" and return
    end

  end

  def prescribe
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @user = User.find(params[:user_id]) rescue nil?
    @patient_diagnoses = current_diagnoses(@patient.person.id)
    @current_weight = Vitals.get_patient_attribute_value(@patient, "current_weight")
    @current_height = Vitals.get_patient_attribute_value(@patient, "current_height")
  end

  def current_diagnoses(patient_id)
    patient = Patient.find(patient_id)
    patient.encounters.current.all(:include => [:observations]).map{|encounter|
      encounter.observations.all(
          :conditions => ["obs.concept_id = ? OR obs.concept_id = ?",
                          ConceptName.find_by_name("DIAGNOSIS").concept_id,
                          ConceptName.find_by_name("DIAGNOSIS, NON-CODED").concept_id])
    }.flatten.compact
  end

  def dm_drugs
    #search_string = (params[:search_string] || '').upcase
    hypertension_medication_concept       = ConceptName.find_by_name("HYPERTENSION MEDICATION").concept_id
    diabetes_medication_concept       = ConceptName.find_by_name("DIABETES MEDICATION").concept_id
    cardiac_medication_concept       = ConceptName.find_by_name("CARDIAC MEDICATION").concept_id
    kidney_failure_medication_concept       = ConceptName.find_by_name("KIDNEY FAILURE CARDIAC MEDICATION").concept_id
    #@drug_concepts = ConceptName.find_by_sql("SELECT * FROM concept_set
    #INNER JOIN drug ON drug.concept_id = concept_set.concept_id WHERE drug.retired = 0 AND
    #concept_set IN (#{hypertension_medication_concept}, #{diabetes_medication_concept}, #{cardiac_medication_concept}, #{kidney_failure_medication_concept})")



    search_string = (params[:search_string] || '').upcase
    filter_list = params[:filter_list].split(/, */) rescue []
    @drug_concepts = ConceptName.find(:all,
                                      :select => "concept_name.name",
                                      :joins => "INNER JOIN drug ON drug.concept_id = concept_name.concept_id AND drug.retired = 0
								 INNER JOIN concept_set ON concept_set.concept_id = concept_name.concept_id",
                                      :conditions => ["concept_name.name LIKE ? AND concept_set IN (#{hypertension_medication_concept}, #{diabetes_medication_concept}, #{cardiac_medication_concept}, #{kidney_failure_medication_concept})", '%' + search_string + '%'],:group => 'drug.concept_id')
    render :text => "<li>" + @drug_concepts.map{|drug_concept| drug_concept.name }.uniq.join("</li><li>") + "</li>"
  end

  def new_prescription

    @patient = Patient.find(params[:patient_id])
    @partial_name = 'drug_set'
    @partial_name = params[:screen] unless params[:screen].blank?
    @drugs = Drug.find(:all,:limit => 20)
    @drug_sets = {}
    @set_names = {}
    @set_descriptions = {}

    GeneralSet.find_all_by_status("active").each do |set|

      @drug_sets[set.set_id] = {}
      @set_names[set.set_id] = set.name
      @set_descriptions[set.set_id] = set.description

      dsets = DrugSet.find_all_by_set_id(set.set_id)
      dsets.each do |d_set|

        @drug_sets[set.set_id][d_set.drug_inventory_id] = {}
        drug = Drug.find(d_set.drug_inventory_id)
        @drug_sets[set.set_id][d_set.drug_inventory_id]["drug_name"] = drug.name
        @drug_sets[set.set_id][d_set.drug_inventory_id]["units"] = drug.units
        @drug_sets[set.set_id][d_set.drug_inventory_id]["duration"] = d_set.duration
        @drug_sets[set.set_id][d_set.drug_inventory_id]["dose"] = d_set.dose rescue drug.dose_strength
        @drug_sets[set.set_id][d_set.drug_inventory_id]["frequency"] = d_set.frequency
      end
    end

    render :layout => false
  end

  def search_for_drugs
    drugs = {}
    Drug.find(:all, :conditions => ["name LIKE (?)",
                                    "#{params[:search_str]}%"],:order => 'name',:limit => 20).map do |drug|
      drugs[drug.id] = { :name => drug.name,:dose_strength =>drug.dose_strength || 1, :unit => drug.units }
    end
    render :text => drugs.to_json
  end

  def prescribes

    @patient    = Patient.find(params["patient_id"]) rescue nil

    d = (session[:datetime].to_date rescue Date.today)
    t = Time.now
    session_date = DateTime.new(d.year, d.month, d.day, t.hour, t.min, t.sec)

    encounter  = current_prescription_encounter(@patient, session_date, params[:user_id])
    encounter.encounter_datetime = session_date
    encounter.save

    params[:drug_formulations] = (params[:drug_formulations] || []).collect{|df| eval(df) } || {}

    params[:drug_formulations].each do |prescription|

      prescription[:prn] = 0 if prescription[:prn].blank?
      auto_expire_date = session_date.to_date + (prescription[:duration].sub(/days/i, "").strip).to_i.days
      drug = Drug.find(prescription[:drug_id])
      dose = prescription[:dose] rescue drug.dose_strength
      DrugOrder.write_order(encounter, @patient, nil, drug, session_date, auto_expire_date, dose,
                            prescription[:frequency], prescription[:prn].to_i)
    end

    #if (@patient)
    #	redirect_to next_task(@patient) and return
    #else
    redirect_to "/patients/treatment_dashboard?patient_id=#{params[:patient_id]}&user_id=#{params[:user_id]}"
  end

  def fully_specified_frequencies
    concept_id = Core::ConceptName.find_by_name('DRUG FREQUENCY CODED').concept_id
    set = Core::ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    frequencies = []
    options = set.each{ | item |
      next if item.concept.blank?
      frequencies << [item.concept.shortname, item.concept.fullname + "(" + item.concept.shortname + ")"]
    }
    frequencies
  end


end
