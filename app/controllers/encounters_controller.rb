
class EncountersController < ApplicationController

  def create

    @retrospective = session[:datetime]
		@retrospective = Time.now if session[:datetime].blank?
    Core::User.current = Core::User.find(@user["user_id"]) rescue nil

    remote_ip = request.remote_ip
    host = request.host_with_port
    #raise @retrospective.to_yaml
    Core::Location.current = Core::Location.find(params[:location_id] || session[:location_id]) rescue nil

    patient = Core::Patient.find(params[:patient_id]) rescue nil

    if !patient.nil?
			
      type = Core::EncounterType.find_by_name(params[:encounter_type]).id rescue nil

      if !type.nil?
        @encounter = Core::Encounter.create(
          :patient_id => patient.id,
          :provider_id => (params[:user_id]),
          :encounter_type => type,
          :location_id => (session[:location_id] || params[:location_id])
        )

        @current = nil

        # raise @encounter.to_yaml

        if !params[:program].blank?

          @program = Core::Program.find_by_concept_id(Core::ConceptName.find_by_name(params[:program]).concept_id) rescue nil
					
          if !@program.nil?

            @program_encounter = Core::ProgramEncounter.find_by_program_id(@program.id,
              :conditions => ["patient_id = ? AND DATE(date_time) = ?",
                patient.id, @retrospective.strftime("%Y-%m-%d")])

            if @program_encounter.blank?

              @program_encounter = Core::ProgramEncounter.create(
                :patient_id => patient.id,
                :date_time => @retrospective,
                :program_id => @program.id
              )

            end
            #if params[:encounter_type].upcase != "VITALS"
            Core::ProgramEncounterDetail.create(
                  :encounter_id => @encounter.id.to_i,
                  :program_encounter_id => @program_encounter.id,
                  :program_id => @program.id
                )
            #end
						
            @current = Core::PatientProgram.find_by_program_id(@program.id,
              :conditions => ["patient_id = ? AND COALESCE(date_completed, '') = ''", patient.id])

            if @current.blank?

              @current = Core::PatientProgram.create(
                :patient_id => patient.id,
                :program_id => @program.id,
                :date_enrolled => @retrospective
              )

            end

            (params[:programs] || []).each do |program|
              (program[:states] || []).each {|state| @current.transition({
                    :state => state["state"],
                    :start_date => (state["state_date"] || Time.now),
                    :end_date => (state["state_date"] || Time.now)
                  }) }

            end

          else

            redirect_to "/encounters/missing_program?program=#{params[:program]}" and return

          end

        end

				if  params[:encounter_type] == "LAB RESULTS"
          #raise params.to_yaml
          create_obs(@encounter , params)

          @task = TaskFlow.new(params[:user_id] || User.first.id, patient.id)
        
          redirect_to params[:next_url] and return if !params[:next_url].blank?
					begin   
						redirect_to @task.asthma_next_task(host,remote_ip).url and return if current_program == "ASTHMA PROGRAM"
						redirect_to @task.epilepsy_next_task(host,remote_ip).url and return if current_program == "EPILEPSY PROGRAM"
            redirect_to @task.hypertension_next_task(host,remote_ip).url and return if current_program == "HYPERTENSION PROGRAM"
						redirect_to @task.next_task(host,remote_ip).url and return
					rescue
						redirect_to "/patients/show/#{params[:patient_id]}?user_id=#{params[:user_id]}&disable=true" and return
					end
        end

        params[:concept].each do |key, value|
          if value.blank?
            next
          end

          if value.class.to_s.downcase != "array"

            concept = Core::ConceptName.find_by_name(key.strip).concept_id rescue nil

            if !concept.nil? and !value.blank?

              if !@program.nil? and !@current.nil?
                selected_state = @program.program_workflows.map(&:program_workflow_states).flatten.select{|pws|
                  pws.concept.fullname.upcase() == value.upcase()
                }.first rescue nil

                @current.transition({
                    :state => "#{value}",
                    :start_date => @retrospective,
                    :end_date => @retrospective
                  }) if !selected_state.nil?
              end
							
              concept_type = nil
              if value.strip.match(/^\d+$/)

                concept_type = "number"

              elsif value.strip.match(/^\d{4}-\d{2}-\d{2}$/)

                concept_type = "date"

              elsif value.strip.match(/^\d{2}\:\d{2}\:\d{2}$/)

                concept_type = "time"

              else

                value_coded = Core::ConceptName.find_by_name(value.strip) rescue nil

                if !value_coded.nil?

                  concept_type = "value_coded"

                else

                  concept_type = "text"

                end

              end

              obs = Core::Observation.create(
                :person_id => @encounter.patient_id,
                :concept_id => concept,
                :location_id => @encounter.location_id,
                :obs_datetime => @encounter.encounter_datetime,
                :encounter_id => @encounter.id
              )
              case concept_type
								
              when "date"

                obs.update_attribute("value_datetime", value)

              when "time"
								obs.update_attribute("value_text", value) if key == "time of seizure"
                obs.update_attribute("value_datetime", "#{Date.today.strftime("%Y-%m-%d")} " + value) if key != "time of seizure"

              when "number"

                obs.update_attribute("value_numeric", value)

              when "value_coded"

                obs.update_attribute("value_coded", value_coded.concept_id)
                obs.update_attribute("value_coded_name_id", value_coded.concept_name_id)

              else
								
                obs.update_attribute("value_text", value)

              end
							
            else
							
							key = key.gsub(" ", "_")
              redirect_to "/encounters/missing_concept?concept=#{key}" and return if !value.blank?

            end

          else

            value.each do |item|
							
              concept = Core::ConceptName.find_by_name(key.strip).concept_id rescue nil

              if !concept.nil? and !item.blank?

                if !@program.nil? and !@current.nil?
                  selected_state = @program.program_workflows.map(&:program_workflow_states).flatten.select{|pws|
                    pws.concept.fullname.upcase() == item.upcase()
                  }.first rescue nil

                  @current.transition({
                      :state => "#{item}",
                      :start_date => @retrospective,
                      :end_date => @retrospective
                    }) if !selected_state.nil?
                end

                concept_type = nil
                if item.strip.match(/^\d+$/)

                  concept_type = "number"

                elsif item.strip.match(/^\d{4}-\d{2}-\d{2}$/)

                  concept_type = "date"

                elsif item.strip.match(/^\d{2}\:\d{2}\:\d{2}$/)

                  concept_type = "time"

                else

                  value_coded = Core::ConceptName.find_by_name(item.strip) rescue nil

                  if !value_coded.nil?

                    concept_type = "value_coded"

                  else

                    concept_type = "text"

                  end

                end

                obs = Core::Observation.create(
                  :person_id => @encounter.patient_id,
                  :concept_id => concept,
                  :location_id => @encounter.location_id,
                  :obs_datetime => @encounter.encounter_datetime,
                  :encounter_id => @encounter.id
                )

                case concept_type
                when "date"

                  obs.update_attribute("value_datetime", item)

                when "time"

                  obs.update_attribute("value_datetime", "#{@retrospective.strftime("%Y-%m-%d")} " + item)

                when "number"

                  obs.update_attribute("value_numeric", item)

                when "value_coded"

                  obs.update_attribute("value_coded", value_coded.concept_id)
                  obs.update_attribute("value_coded_name_id", value_coded.concept_name_id)

                else

                  obs.update_attribute("value_text", item)

                end

              else

                redirect_to "/encounters/missing_concept?concept=#{item}" and return if !item.blank?

              end

            end

          end
					
        end if !params[:concept].nil?


        if !params[:prescription].nil?

          params[:prescription].each do |prescription|

            @suggestions = prescription[:suggestion] || ['New Prescription']
            @patient = Core::Patient.find(params[:patient_id] || session[:patient_id]) rescue nil

            unless params[:location]
              session_date = session[:datetime] || params[:encounter_datetime] || Time.now()
            else
              session_date = params[:encounter_datetime] #Use encounter_datetime passed during import
            end
            # set current location via params if given
            Core::Location.current_location = Core::Location.find(params[:location]) if params[:location]

            @diagnosis = Core::Observation.find(prescription[:diagnosis]) rescue nil
            @suggestions.each do |suggestion|
              unless (suggestion.blank? || suggestion == '0' || suggestion == 'New Prescription')
                @order = Core::DrugOrder.find(suggestion)
                Core::DrugOrder.clone_order(@encounter, @patient, @diagnosis, @order)
              else

                @formulation = (prescription[:formulation] || '').upcase
                @drug = Core::Drug.find_by_name(@formulation) rescue nil
                unless @drug
                  flash[:notice] = "No matching drugs found for formulation #{prescription[:formulation]}"
                  # render :give_drugs, :patient_id => params[:patient_id]
                  # return
                end
                start_date = session_date
                auto_expire_date = session_date.to_date + prescription[:duration].to_i.days
                prn = prescription[:prn].to_i

                Core::DrugOrder.write_order(@encounter, @patient, @diagnosis, @drug,
                  start_date, auto_expire_date, [prescription[:morning_dose],
                    prescription[:afternoon_dose], prescription[:evening_dose],
                    prescription[:night_dose]], prescription[:type_of_prescription], prn)

              end
            end

          end

        end
				
      else

        redirect_to "/encounters/missing_encounter_type?encounter_type=#{params[:encounter_type]}" and return

      end

			if params[:encounter_type] == "TREATMENT"
       if  params[:advise] == "true"
          redirect_to "/patients/treatment_dashboard/#{params[:patient_id]}?user_id=#{params[:user_id]}" and return
       end

        link = get_global_property_value("prescription.types").upcase rescue []
				if  params[:concept]["Prescribe Drugs"].to_s.upcase == "YES"
					if link == "ADVANCED PRESCRIPTION"
            redirect_to "/prescriptions/generic_advanced_prescription?user_id=#{@user["user_id"]}&patient_id=#{params[:patient_id]}" and return
          elsif link == "PRESCRIPTION WITH SETS"
            redirect_to "/prescriptions/new_prescription?user_id=#{@user["user_id"]}&patient_id=#{params[:patient_id]}" and return
          else
            redirect_to "/prescriptions/prescribe?user_id=#{@user["user_id"]}&patient_id=#{params[:patient_id]}" and return
          end
        elsif params[:concept]["Prescribe Drugs"].blank?
          redirect_to "/protocol_patients/assessment?patient_id=#{params[:patient_id]}&user_id=#{params[:user_id]}&disable=true" and return
				else
          redirect_to "/patients/show/#{params[:patient_id]}?user_id=#{params[:user_id]}&disable=true" and return
				end
			end

			
      redirect_to params[:next_url] and return if !params[:next_url].nil?
			
			if params[:encounter_type].to_s.upcase == "APPOINTMENT"
        print_and_redirect("/patients/specific_patient_visit_date_label/#{params[:patient_id]}?user_id=#{params[:user_id]}","/patients/show/#{params[:patient_id]}?user_id=#{params[:user_id]}")
        return
      elsif params[:encounter_type].to_s.upcase == "UPDATE HIV STATUS"
        if params[:concept]['Patient enrolled in HIV program'].upcase == "YES"
          port = request.host_with_port.split(":")[1]
          link = get_global_property_value("bart2.url").to_s rescue []
          unless link.blank?
            redirect_to "#{link}/encounters/new/hiv_reception?show&patient_id=#{params[:patient_id]}&return_ip=http://#{request.remote_ip}:#{port}/patients/show/#{params[:patient_id]}?user_id=#{params[:user_id]}" and return
          end
        end
			elsif params[:encounter_type].to_s.upcase == "EPILEPSY CLINIC VISIT"
        @mrdt = Vitals.current_vitals(Patient.find(params[:patient_id]), "Patient in active seizure")
						
        unless @mrdt.blank?
          @mrdt = @mrdt.value_text.upcase rescue Core::ConceptName.find_by_concept_id(@mrdt.value_coded).name.upcase
          if @mrdt == "YES"
            redirect_to "/protocol_patients/clinic_visit?patient_id=#{params[:patient_id]}&user_id=#{params[:user_id]}&repeat=true"
            return
          end
        end
			end

      @task = TaskFlow.new(params[:user_id] || User.first.id, patient.id)

			begin
				redirect_to @task.asthma_next_task(host,remote_ip).url and return if current_program == "ASTHMA PROGRAM"
				redirect_to @task.epilepsy_next_task(host,remote_ip).url and return if current_program == "EPILEPSY PROGRAM"
				redirect_to @task.next_task(host,remote_ip).url and return
			rescue
				redirect_to "/patients/show/#{params[:patient_id]}?user_id=#{params[:user_id]}&disable=true" and return
			end

    end

  end


  def life_advise
  	
    	@patient = Core::Patient.find(params[:patient_id])
    	@user = Core::User.find(params[:user_id])
    	 current_date = (!session[:datetime].nil? ? session[:datetime].to_date : Date.today)
    previous_days = 3.months
    current_date = current_date - previous_days
    @age = @patient.age
    @sbp = Core::Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'SBP' LIMIT 1)
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0

    @previous_sbp = Core::Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'SBP' LIMIT 1)
                   AND DATE(obs_datetime) <= #{current_date}
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0

    @previous_dbp = Core::Observation.find_by_sql("SELECT * from obs
               WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'DBP' LIMIT 1)
               AND DATE(obs_datetime) <= #{current_date}
               AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0


    @dbp = Core::Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'DBP' LIMIT 1)
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0

    @bmi = Core::Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'bmi' LIMIT 1)
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.to_s.split(":")[1].squish.to_f.round(2) rescue 0

    @smoking = Vitals.current_vitals(@patient, "current smoker").to_s.split(":")[1].squish.upcase rescue "Unknown"
    @drinking = Vitals.current_vitals(@patient, "Does the patient drink alcohol?").to_s.split(":")[1].squish.upcase rescue "Unknown"

    current_date = current_date + 2.months
    
    @previous_treatment = check_encounter(@patient, "TREATMENT", current_date)

    @bp = (@sbp / @dbp).to_f rescue 0
    @previous_bp = (@previous_sbp / @previous_dbp).to_f rescue 0
    @normal_bp = (180/100)

    @category = "Mild"

    if ! @sbp.blank? and ! @dbp.blank?
          if (@sbp >= 140 and @sbp < 160) and (@dbp >= 100 and @dbp < 110)
            @category = "Mild"
          elsif (@sbp >= 160 and @sbp < 180) and (@dbp >= 90 and @dbp < 100)
            @category = "Moderate"
          elsif (@sbp >= 180) and (@dbp >= 110)
            @category = "Severe"
          end
    end
  end
  
  def list_observations
    obs = []
    encounter = Core::Encounter.find(params[:encounter_id])

    if encounter.type.name.upcase == "DISPENSING"
      obs = encounter.observations.collect{|o|
        drug = Core::Drug.find(o.value_drug).name
        mixed = "#{drug} #{o.to_piped_s.humanize}"
        [o.id, mixed] rescue nil
      }.compact
    elsif encounter.type.name.upcase == "TREATMENT"
     
      if encounter.observations.length > 0
	      obs = encounter.observations.collect{|o|
		[o.id, o.to_piped_s.humanize] rescue nil
	      }.compact
      end
       if encounter.orders.length > 0
	      obs += encounter.orders.collect{|o|
		["drg", o.to_s]
	      }
      end
    else
      obs = encounter.observations.collect{|o|
        [o.id, o.to_piped_s.humanize] rescue nil
      }.compact
    end

    render :text => obs.to_json
  end

  def void
    prog = Core::ProgramEncounterDetail.find_by_encounter_id(params[:encounter_id]) rescue nil

    unless prog.nil?
      prog.void

      encounter = Core::Encounter.find(params[:encounter_id]) rescue nil

      unless encounter.nil?
        encounter.void
      end

    end


    render :text => [].to_json
  end

  def list_encounters
    result = []

    program = Core::ProgramEncounter.find(params[:program_id]) rescue nil

    unless program.nil?
      result = program.program_encounter_types.find(:all, :joins => [:encounter],
        :conditions => ["encounter.voided = 0"],
        :order => ["encounter_datetime DESC"]).collect{|e|
        [
          e.encounter_id, e.encounter.type.name.titleize,
          e.encounter.encounter_datetime.strftime("%H:%M"),
          e.encounter.creator,
          e.encounter.encounter_datetime.strftime("%d-%b-%Y")
        ]
      }
    end

    render :text => result.to_json
  end

  def static_locations
    search_string = (params[:search_string] || "").upcase
    extras = ["Health Facility", "Home", "TBA", "Other"]

    locations = []

    File.open(RAILS_ROOT + "/public/data/locations.txt", "r").each{ |loc|
      locations << loc if loc.upcase.strip.match(search_string)
    }

    if params[:extras]
      extras.each{|loc| locations << loc if loc.upcase.strip.match(search_string)}
    end

    render :text => "<li></li><li " + locations.map{|location| "value=\"#{location.strip}\">#{location.strip}" }.join("</li><li ") + "</li>"

  end

  def diagnoses

    search_string         = (params[:search] || '').upcase

    diagnosis_concepts    = Core::Concept.find_by_name("Qech outpatient diagnosis list").concept_members.collect{|c| c.concept.fullname}.sort.uniq rescue ["Unknown"]

    @results = diagnosis_concepts.collect{|e| e}.delete_if{|x| !x.upcase.match(/^#{search_string}/)}

    render :text => "<li>" + @results.join("</li><li>") + "</li>"

  end

	def create_obs(encounter , params)
		# Observation handling
    #raise params['provider'].to_yaml
		(params[:observations] || []).each do |observation|
			next if observation[:concept_name] == ""
			# Check to see if any values are part of this observation
			# This keeps us from saving empty observations
			values = ['coded_or_text', 'coded_or_text_multiple', 'group_id', 'boolean', 'coded', 'drug', 'datetime', 'numeric', 'modifier', 'text'].map { |value_name|
				observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
			}.compact

			next if values.length == 0

			observation[:value_text] = observation[:value_text].join(", ") if observation[:value_text].present? && observation[:value_text].is_a?(Array)
			observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
			observation[:encounter_id] = encounter.id
			observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
			observation[:person_id] ||= encounter.patient_id
			observation[:concept_name].upcase ||= "DIAGNOSIS" if encounter.type.name.upcase == "OUTPATIENT DIAGNOSIS"

			# Handle multiple select

			if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(String)
				observation[:value_coded_or_text_multiple] = observation[:value_coded_or_text_multiple].split(';')
			end

			if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array)
				observation[:value_coded_or_text_multiple].compact!
				observation[:value_coded_or_text_multiple].reject!{|value| value.blank?}
			end

			# convert values from 'mmol/litre' to 'mg/declitre'
			if(observation[:measurement_unit])
				observation[:value_numeric] = observation[:value_numeric].to_f * 18 if ( observation[:measurement_unit] == "mmol/l")
				observation.delete(:measurement_unit)
			end

			if(!observation[:parent_concept_name].blank?)
				concept_id = Core::Concept.find_by_name(observation[:parent_concept_name]).id rescue nil
				observation[:obs_group_id] = Observation.find(:last, :conditions=> ['concept_id = ? AND encounter_id = ?', concept_id, encounter.id], :order => "obs_id ASC, date_created ASC").id rescue ""
				observation.delete(:parent_concept_name)
			else
				observation.delete(:parent_concept_name)
				observation.delete(:obs_group_id)
			end

			extracted_value_numerics = observation[:value_numeric]
			extracted_value_coded_or_text = observation[:value_coded_or_text]

			#TODO : Added this block with Yam, but it needs some testing.
			if params[:location]
				if encounter.encounter_type == Core::EncounterType.find_by_name("ART ADHERENCE").id
					passed_concept_id = Core::Concept.find_by_name(observation[:concept_name]).concept_id rescue -1
					obs_concept_id = Core::Concept.find_by_name("AMOUNT OF DRUG BROUGHT TO CLINIC").concept_id rescue -1
					if observation[:order_id].blank? && passed_concept_id == obs_concept_id
						order_id = Core::Order.find(:first,
							:select => "orders.order_id",
							:joins => "INNER JOIN drug_order USING (order_id)",
							:conditions => ["orders.patient_id = ? AND drug_order.drug_inventory_id = ?
										  AND orders.start_date < ?", encounter.patient_id,
                observation[:value_drug], encounter.encounter_datetime.to_date],
							:order => "orders.start_date DESC").order_id rescue nil
						if !order_id.blank?
							observation[:order_id] = order_id
						end
					end
				end
			end

			if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array) && !observation[:value_coded_or_text_multiple].blank?
				values = observation.delete(:value_coded_or_text_multiple)
				values.each do |value|
					observation[:value_coded_or_text] = value
					if observation[:concept_name].humanize == "Tests ordered"
						observation[:accession_number] = Core::Observation.new_accession_number
					end

					observation = update_observation_value(observation)

          Core::Observation.create(observation)
				end
			elsif extracted_value_numerics.class == Array
				extracted_value_numerics.each do |value_numeric|
					observation[:value_numeric] = value_numeric

				  if !observation[:value_numeric].blank? && !(Float(observation[:value_numeric]) rescue false)
						observation[:value_text] = observation[:value_numeric]
						observation.delete(:value_numeric)
					end

					Observation.create(observation)
				end
			else
				observation.delete(:value_coded_or_text_multiple)
				observation = update_observation_value(observation) if !observation[:value_coded_or_text].blank?

				if !observation[:value_numeric].blank? && !(Float(observation[:value_numeric]) rescue false)
					observation[:value_text] = observation[:value_numeric]
					observation.delete(:value_numeric)
				end

				Core::Observation.create(observation)
			end
		end
  end

	def update_observation_value(observation)
		value = observation[:value_coded_or_text]
		value_coded_name = Core::ConceptName.find_by_name(value)

		if value_coded_name.blank?
			observation[:value_text] = value
		else
			observation[:value_coded_name_id] = value_coded_name.concept_name_id
			observation[:value_coded] = value_coded_name.concept_id
		end
		observation.delete(:value_coded_or_text)
		return observation
	end

	def new
		remote_ip = request.remote_ip
    host = request.host_with_port
		@patient = Core::Patient.find(params[:patient_id] || session[:patient_id])
		#@patient_bean = PatientService.get_patient(@patient.person)
		session_date = session[:datetime].to_date rescue Date.today
		
		if session[:datetime]
			@retrospective = true
		else
			@retrospective = false
		end
    
		#@current_height = Vitals.get_patient_attribute_value(@patient, "current_height")
		#@min_weight = Vitals.get_patient_attribute_value(@patient, "min_weight")
    #@max_weight = Vitals.get_patient_attribute_value(@patient, "max_weight")
    #@min_height = Vitals.get_patient_attribute_value(@patient, "min_height")
    #@max_height = Vitals.get_patient_attribute_value(@patient, "max_height")
    #@given_arvs_before = given_arvs_before(@patient)
    @current_encounters = @patient.encounters.find_by_date(session_date)
    #@previous_tb_visit = previous_tb_visit(@patient.id)
    @is_patient_pregnant_value = nil
    @is_patient_breast_feeding_value = nil

    if (params[:encounter_type].upcase rescue '') == 'APPOINTMENT'
      @todays_date = session_date
      logger.info('========================== Suggesting appointment date =================================== @ '  + Time.now.to_s)
      @suggested_appointment_date = suggest_appointment_date
      logger.info('========================== Completed suggesting appointment date =================================== @ '  + Time.now.to_s)
    end

		#@number_of_days_to_add_to_next_appointment_date = number_of_days_to_add_to_next_appointment_date(@patient, session[:datetime] || Date.today)

		@location_transferred_to = []
		if (params[:encounter_type].upcase rescue '') == 'APPOINTMENT'
		  @old_appointment = nil
		  @report_url = nil
		  @report_url =  params[:report_url]  and @old_appointment = params[:old_appointment] if !params[:report_url].nil?
		  @current_encounters.reverse.each do |enc|
        enc.observations.each do |o|
          @location_transferred_to << o.to_s_location_name.strip if o.to_s.include?("Transfer out to") rescue nil
        end
      end
		end

		if (params[:encounter_type].upcase rescue '') == "DIABETES_INITIAL_QUESTIONS"
			encounter_available = Core::Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
          @patient.id, Core::EncounterType.find_by_name("DIABETES INITIAL QUESTIONS").id],
        :order =>'encounter_datetime DESC',:limit => 1)

			if encounter_available.blank?
				@has_initial_questions = false
			else
				@has_initial_questions = true
			end
		end

		if ['GENERAL_HEALTH', 'DIABETES_HISTORY', 'PAST_DIABETES_MEDICAL_HISTORY'].include?((params[:encounter_type].upcase rescue ''))

			encounter = params[:encounter_type].upcase
			encounter_available = Core::Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
          @patient.id, Core::EncounterType.find_by_name(encounter.humanize.upcase).id],
        :order =>'encounter_datetime DESC',:limit => 1)
			@has_diabetes_history = false
			@has_general_health = false
			@past_diabetes_medical_history = false

			if encounter == 'GENERAL_HEALTH' && !encounter_available.blank?
				@has_general_health = true
			elsif encounter == 'DIABETES_HISTORY' && !encounter_available.blank?
				@has_diabetes_history = true
			elsif encounter == 'PAST_DIABETES_MEDICAL_HISTORY' && !encounter_available.blank?
				@past_diabetes_medical_history = true
			end

		end


		redirect_to "/" and return unless @patient

		redirect_to next_task(@patient, host,remote_ip) and return unless params[:encounter_type]

		redirect_to :action => :create, 'encounter[encounter_type_name]' => params[:encounter_type].upcase, 'encounter[patient_id]' => @patient.id and return if ['registration'].include?(params[:encounter_type])

		
		render :action => params[:encounter_type].downcase if params[:encounter_type]
	end

	def suggest_appointment_date
		#for now we disable this because we are already checking for this
		#in the browser - the method is suggested_return_date
		#@number_of_days_to_add_to_next_appointment_date = number_of_days_to_add_to_next_appointment_date(@patient, session[:datetime] || Date.today)

		dispensed_date = session[:datetime].to_date rescue Date.today
		expiry_date = prescription_expiry_date(@patient, dispensed_date)
		
		#if the patient is a child (age 14 or less) and the peads clinic days are set - we
		#use the peads clinic days to set the next appointment date
		peads_clinic_days = CoreService.get_global_property_value('peads.clinic.days')

		if (@patient.age <= 14 && !peads_clinic_days.blank?)
			clinic_days = peads_clinic_days
		else
			clinic_days = CoreService.get_global_property_value('clinic.days') || 'Monday,Tuesday,Wednesday,Thursday,Friday'
		end
		clinic_days = clinic_days.split(',')

		bookings = bookings_within_range(expiry_date)

		clinic_holidays = CoreService.get_global_property_value('clinic.holidays')
		clinic_holidays = clinic_holidays.split(',').map{|day|day.to_date}.join(',').split(',') rescue []

		return suggested_date(expiry_date ,clinic_holidays, bookings, clinic_days)
	end

  def drugs_given_on(patient, date = Date.today)
    clinic_encounters = ["APPOINTMENT", "VITALS","ART_INITIAL","HIV RECEPTION",
      "ART VISIT","TREATMENT","DISPENSING",'ART ADHERENCE','HIV STAGING']
    encounter_type_ids = Core::EncounterType.find_all_by_name(clinic_encounters).collect{|e|e.id}

    latest_encounter_date = Core::Encounter.find(:first,
      :conditions =>["patient_id = ? AND encounter_datetime >= ?
        AND encounter_datetime <=? AND encounter_type IN(?)",
        patient.id,date.strftime('%Y-%m-%d 00:00:00'),
        date.strftime('%Y-%m-%d 23:59:59'),encounter_type_ids],
      :order =>"encounter_datetime DESC").encounter_datetime rescue nil

    return [] if latest_encounter_date.blank?

    start_date = latest_encounter_date.strftime('%Y-%m-%d 00:00:00')
    end_date = latest_encounter_date.strftime('%Y-%m-%d 23:59:59')

    concept_id = Core::Concept.find_by_name('AMOUNT DISPENSED').id
    Core::Order.find(:all,:joins =>"INNER JOIN obs ON obs.order_id = orders.order_id",
      :conditions =>["obs.person_id = ? AND obs.concept_id = ?
        AND obs_datetime >=? AND obs_datetime <=?",
        patient.id,concept_id,start_date,end_date],
      :order =>"obs_datetime")
  end

	def prescription_expiry_date(patient, dispensed_date)
    session_date = dispensed_date.to_date

    arvs_given = false

    #get all drug dispensed on set clinic day
		drugs_given_on = drugs_given_on(patient, session_date)

		orders_made = drugs_given_on.reject do |o|
      !MedicationService.tb_medication(o.drug_order.drug)
    end

		auto_expire_date = Date.today + 2.days

		if orders_made.blank?
			orders_made = drugs_given_on
			auto_expire_date = orders_made.sort_by(&:auto_expire_date).first.auto_expire_date.to_date unless orders_made.blank?

      regimen_type_concept = nil
      (orders_made || []).each do |o|
        next unless MedicationService.arv(o.drug_order.drug)
        regimen_type_concept = Core::ConceptName.find_by_name("ARV regimens received abstracted construct").concept_id
        arvs_given = true
        break
      end
		else
			auto_expire_date = orders_made.sort_by(&:auto_expire_date).first.auto_expire_date.to_date
      regimen_type_concept = Core::ConceptName.find_by_name("TB REGIMEN TYPE").concept_id
		end

		treatment_encounter = orders_made.first

		treatment_encounter = treatment_encounter.encounter.id rescue treatment_encounter.encounter_id rescue []
		#raise treatment_encounter.to_yaml
    arv_regimen_obs = Core::Observation.find_by_sql("SELECT * FROM obs
      WHERE concept_id = #{regimen_type_concept}
      AND encounter_id = #{treatment_encounter} LIMIT 1") rescue []

		arv_regimen_type = ""
		unless arv_regimen_obs.blank?
			arv_regimen_type = arv_regimen_obs.to_s
		end

		starter_pack = false
		if arv_regimen_type.match(/STARTER PACK/i)
			starter_pack = true
		end

    #==========================================================================================
    calculated_expire_date = auto_expire_date

    order = orders_made.sort_by(&:auto_expire_date).first

    #............................................................................................
    amounts_brought_to_clinic = Core::Observation.find_by_sql("SELECT * FROM obs
      INNER JOIN drug_order USING (order_id)
      WHERE obs.concept_id = #{Core::ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').concept_id}
      AND drug_order.drug_inventory_id = #{order.drug_order.drug_inventory_id}
      AND obs.obs_datetime >= '#{session_date.to_date}'
      AND obs.obs_datetime <= '#{session_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
      AND person_id = #{patient.id}") rescue []

    total_brought_to_clinic = amounts_brought_to_clinic.sum{|amount| amount.value_numeric}

    total_brought_to_clinic = total_brought_to_clinic + amounts_brought_to_clinic.sum{|amount| (amount.value_text.to_f rescue 0)}

    hanging_pills_duration = ((total_brought_to_clinic)/order.drug_order.equivalent_daily_dose).to_i rescue 0

    expire_date = (order.auto_expire_date + hanging_pills_duration.days) rescue Date.today

    calculated_expire_date = expire_date.to_date if expire_date.to_date > calculated_expire_date

    #............................................................................................


    auto_expire_date = calculated_expire_date

		buffer = 0
		if starter_pack
			buffer = 1
		else
			buffer = 2
		end

		buffer = 0 if !arvs_given
		return auto_expire_date - buffer.days
	end

  def bookings_within_range(end_date = nil)
    clinic_days = Core::GlobalProperty.find_by_property("clinic.days")
    clinic_days = clinic_days.property_value.split(',') rescue 'Monday,Tuesday,Wednesday,Thursday,Friday'.split(',')

    start_date = (end_date - 4.days)
    booked_dates = [end_date]

    (1.upto(4)).each do |num|
      booked_dates << (end_date - num.day)
    end

    clinic_holidays = CoreService.get_global_property_value('clinic.holidays')
    clinic_holidays = clinic_holidays.split(',').map{|day|day.to_date}.join(',').split(',') rescue []
    return_booked_dates = []

    unless clinic_holidays.blank?
      (booked_dates || []).each do |date|
        next if is_holiday(date,clinic_holidays)
        return_booked_dates << date
      end
    else
      return_booked_dates = booked_dates
    end

    return return_booked_dates
  end

	def suggested_date(expiry_date, holidays, bookings, clinic_days)
    bookings.delete_if{|bd| holidays.collect{|h|h.to_date.to_s[5..-1]}.include?(bd.to_s[5..-1])}
    recommended_date = nil
    clinic_appointment_limit = CoreService.get_global_property_value('clinic.appointment.limit').to_i rescue 0

    @encounter_type = Core::EncounterType.find_by_name('APPOINTMENT')
    @concept_id = Core::ConceptName.find_by_name('APPOINTMENT DATE').concept_id

    number_of_bookings = {}

    (bookings || []).sort.reverse.each do |date|
      next if not clinic_days.collect{|c|c.upcase}.include?(date.strftime('%A').upcase)
      limit = number_of_booked_patients(date.to_date).to_i rescue 0
      if limit < clinic_appointment_limit
        recommended_date = date
        break
      else
        number_of_bookings[date] = limit
      end
    end

    (number_of_bookings || {}).sort_by { |dates,num| num }.each do |dates , num|
      next if not clinic_days.collect{|c|c.upcase}.include?(dates.strftime('%A').upcase)
      recommended_date = dates
      break
    end if recommended_date.blank?

    recommended_date = expiry_date if recommended_date.blank?
    return recommended_date
	end

  def assign_close_to_expire_date(set_date,auto_expire_date)
    if (set_date < auto_expire_date)
      while (set_date < auto_expire_date)
        set_date = set_date + 1.day
      end
      #Give the patient a 2 day buffer*/
      set_date = set_date - 1.day
    end
    return set_date
  end

  def is_holiday(suggest_date, holidays)
		holiday = false;
		holidays.each do |h|
			if (h.to_date.strftime('%B %d') == suggest_date.strftime('%B %d'))
				holiday = true;
			end
		end
		return holiday
	end
end
