class ReportController < ApplicationController
  def index
  end

  def menu
   @durations, @path = ReportHelper.report_duration(params[:type])
  end

  def demographic_and_clinical
   @start_date = "#{params[:year]}/#{params[:month]}/01".to_date
   @end_date = @start_date.end_of_month
  end

  def among_those_with_hypertension
   @start_date = "#{params[:year]}/#{params[:month]}/01".to_date
   @end_date = @start_date.end_of_month

   htn_patients = Core::PatientProgram.find(:all, :conditions => ["program_id = ? ",
                                                                  Core::Program.find_by_name("HYPERTENSION PROGRAM").id])

   @htn_patients = htn_patients.collect { |x| x.patient_id }.uniq


   @htn_patients_in_month = Core::Encounter.find_by_sql("SELECT DISTINCT patient_id FROM encounter
                       WHERE encounter_datetime BETWEEN '#{@start_date.strftime('%Y-%m-%d 00:00:00')}'
                       AND '#{@end_date.strftime('%Y-%m-%d 23:59:59')}' AND patient_id IN
                       (#{@htn_patients.blank? ? -1 : @htn_patients.join(",")})
                       AND voided = 0").collect { |x| x.patient_id }

  end

  def alive_and_in_care_report
   @start_date = "#{params[:year]}/#{params[:month]}/01".to_date
   @end_date = @start_date.end_of_month
  end

  def program_evaluation_baseline

  end

  def program_evaluation_followup

  end

  def program_impact_report

  end

  def drill_down

  end

  def total_screened

   bp_concepts = Core::ConceptName.find(:all,:conditions => ["name in (?)",
                                  ['Systolic blood pressure','Diastolic blood pressure']]).collect { |x| x.concept_id }

   patients = Core::Observation.patients_with_particular_observations(bp_concepts,
                                params[:start_date].to_date,params[:end_date].to_date)

   patients = [-1] if patients.blank? #this line handles empty arrays that make the queries not work

   unless params[:category].blank?
    case params[:category]
     when "gender"
      patients = Core::Person.find(:all, :conditions => ["person_id in (?) AND COALESCE(gender,'unknown') in (?)",
                                                         patients,params[:gender] ]).collect{ |x| x.person_id}
     when "age"
      patients = Core::Person.find_by_sql("SELECT person_id,
               COALESCE(((to_days('#{params[:end_date]}') - to_days(`person`.`birthdate`))/365.25),'unknown') AS age
               FROM person WHERE person_id in (#{patients.join(',')}) AND voided=0
               HAVING age BETWEEN '#{params[:start_age]}' AND '#{params[:end_age]}'").collect { |x| x.person_id }

     when "age_median"

      ages = Core::Person.find_by_sql("SELECT COALESCE(((to_days('#{params[:end_date]}') - to_days(`person`.`birthdate`))/365.25),0)
               AS age FROM person WHERE person_id in (#{patients.join(',')}) AND voided=0").collect { |x| x.age.to_i }
      patients = median(ages)

     when "bmi_median"
      bmi_concept = Core::Concept.find_by_name("BMI").concept_id
      bmi = Core::Observation.find_by_sql("SELECT person_id, COALESCE(value_numeric,0) as value_numeric FROM obs M
                                         WHERE person_id in (#{patients.join(',')}) AND
                                         obs_datetime = (SELECT MAX(obs_datetime) FROM obs
                                         WHERE person_id = M.person_id  AND voided = 0 AND
                                         obs_datetime BETWEEN '#{params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')}'
                                         AND '#{params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')}' AND
                                         concept_id = #{bmi_concept} ) AND concept_id = #{bmi_concept}").collect{ |x|x.value_numeric }


      patients = bmi.blank? ? 0 : median(bmi)
     when "bmi"
      bmi_concept = Core::Concept.find_by_name("BMI").concept_id

      patients = Core::Observation.find_by_sql("SELECT person_id, COALESCE(value_numeric,0) as value_numeric FROM obs M
                                         WHERE person_id in (#{patients.join(',')}) AND
                                         obs_datetime = (SELECT MAX(obs_datetime) FROM obs
                                         WHERE person_id = M.person_id  AND voided = 0 AND
                                         obs_datetime BETWEEN '#{params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')}'
                                         AND '#{params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')}' AND
                                         concept_id = #{bmi_concept} ) AND concept_id = #{bmi_concept} HAVING
                                         value_numeric BETWEEN '#{params[:start_bmi]}' AND '#{params[:end_bmi]}'").collect { |x| x.person_id }

     when "bp_classification"

      sbp_concept = Core::Concept.find_by_name('Systolic blood pressure').id
      dbp_concept = Core::Concept.find_by_name('Diastolic blood pressure').id

      patients = Core::Observation.find_by_sql("SELECT DISTINCT o.person_id, (SELECT MAX(obs_datetime) FROM obs
                                         WHERE person_id = o.person_id AND voided = 0 AND
                                         obs_datetime BETWEEN '#{params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')}'
                                         AND '#{params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')}' AND
                                         concept_id in (#{dbp_concept},#{sbp_concept}) ) AS max_date,
                                        (SELECT COALESCE(value_numeric,0) FROM obs WHERE obs_datetime = max_date
                                        AND concept_id = #{sbp_concept} AND person_id = o.person_id LIMIT 1) AS SBP,
                                        (SELECT COALESCE(value_numeric,0) FROM obs WHERE obs_datetime = max_date
                                        AND concept_id = #{dbp_concept} AND person_id = o.person_id LIMIT 1) AS DBP
                                        FROM obs as o WHERE o.person_id in (#{patients.join(',')}) HAVING SBP
                                        BETWEEN #{params[:start_sbp]} AND #{params[:end_sbp]} AND DBP BETWEEN
                                        #{params[:start_dbp]} AND #{params[:end_dbp]}").collect { |x| x.person_id }

     when "diagnosis_time"
      diag_concept = Core::Concept.find_by_name('Cardiovascular system diagnosis').id

      patients = Core::Observation.find_by_sql("SELECT person_id, MIN(obs_datetime) as min_date
                                                FROM obs WHERE concept_id = #{diag_concept} AND person_id
                                                in (#{patients.join(',')}) GROUP BY person_id HAVING min_date
                                                BETWEEN '#{params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')}'
                                                AND '#{params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')}'").collect { |x| x.person_id }
     when "outcome"

      outcomes = {"alive" => "'On treatment','Lifestyle Changes Only'",
                  "dead" => "'Patient died'", 'defaulted' => "'Patient defaulted'",
                  'transferred' => "'Patient transferred out'"}

      htn_program = Core::Program.find_by_name("HYPERTENSION PROGRAM").id

      patients = Core::PatientState.find_by_sql("SELECT DISTINCT p.patient_id FROM patient p
                INNER JOIN  patient_program pp on pp.patient_id = p.patient_id
                inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                INNER JOIN  program_workflow_state pw ON
                pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{htn_program},'#{params[:end_date].to_date}')
                INNER JOIN concept_name c ON c.concept_id = pw.concept_id WHERE
                ps.start_date <= '#{params[:end_date].to_date}'
                AND ps.start_date >= '#{params[:start_date].to_date}'
                AND c.name IN (#{outcomes[params[:outcome]]})
                AND p.patient_id IN (#{patients.join(',')})").collect { |x| x.patient_id }

     when "alive"

     when "defaulted"

    end


   end

   render :json => patients.to_json
  end

  def total_screened_by_outcome(start_date, end_date, outcome)

  end

  def total_screen_by_place_of_diagnosis(start_date, end_date, location)

  end

  def total_screened_by_diagnosis(start_date, end_date, diagnosis)

  end

  def those_with_htn_fields

   case params[:category]
    when "gender"
     patients = Core::Person.find(:all,
                                  :conditions => ["COALESCE(gender,'Unknown') = ?
                                   AND person_id in (?)",params[:gender],
                                  params[:ids].split(",")]).collect { |x| x.person_id }
    when "age"
     patients = Core::Person.find_by_sql("SELECT DISTINCT person_id FROM person WHERE voided = 0 AND
             COALESCE(((to_days('#{params[:end_date]}') - to_days(`person`.`birthdate`))/365.25),'unknown')
             BETWEEN '#{params[:start_age]}' AND '#{params[:end_age]}'
             AND person_id in (#{(params[:ids].blank? ? -1 : params[:ids])})").collect { |x| x.person_id }

    when "risk factors"
     factor = Core::Concept.find_by_name(params[:factor]).id
     answer = Core::Concept.find_by_name(params[:answer]).id rescue 'unknown'

     patients = Core::Observation.find_by_sql("SELECT DISTINCT m.person_id,m.value_text FROM obs m
                                               WHERE person_id in  (#{(params[:ids].blank? ? -1 : params[:ids])}) AND
                                               obs_datetime = (SELECT MAX(obs_datetime) FROM obs
                                               WHERE person_id = m.person_id AND voided = 0 AND
                                               obs_datetime <= '#{params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')}' AND
                                               concept_id = #{factor} ) AND concept_id = #{factor}
                                               AND value_coded = #{answer} ").collect { |x| x.person_id }

    when "bmi"
     bmi_concept = Core::Concept.find_by_name("BMI").concept_id

     patients = Core::Observation.find_by_sql("SELECT DISTINCT m.person_id, COALESCE(m.value_numeric, m.value_text) AS bmi FROM obs m
                                               WHERE person_id in  (#{(params[:ids].blank? ? -1 : params[:ids])}) AND
                                               obs_datetime = (SELECT MAX(obs_datetime) FROM obs
                                               WHERE person_id = m.person_id AND voided = 0 AND
                                               obs_datetime BETWEEN '#{params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')}'
                                               AND '#{params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')}' AND
                                               concept_id = #{bmi_concept} ) AND concept_id = #{bmi_concept} HAVING
                                               bmi BETWEEN #{params[:start_bmi]} AND #{params[:end_bmi]} ").collect { |x| x.person_id }

    when "art_regimen"
     regimen_category = Core::Concept.find_by_name("Regimen Category").concept_id
     patients = Core::Observation.find_by_sql("SELECT DISTINCT m.person_id,m.value_text FROM obs m
                                               WHERE person_id in  (#{(params[:ids].blank? ? -1 : params[:ids])}) AND
                                               obs_datetime = (SELECT MAX(obs_datetime) FROM obs
                                               WHERE person_id = m.person_id AND voided = 0 AND
                                               obs_datetime <= '#{params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')}' AND
                                               concept_id = #{regimen_category} ) AND concept_id = #{regimen_category}
                                               AND value_text = '#{params[:regimen]}' ").collect { |x| x.person_id }

    when "unknown_regimen"
     regimen_category = Core::Concept.find_by_name("Regimen Category").concept_id
     patients = Core::Person.find_by_sql("SELECT person_id FROM person WHERE person_id NOT IN
                          (SELECT DISTINCT person_id FROM obs WHERE concept_id = #{regimen_category}
                          AND voided = 0 AND obs_datetime <= '#{params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')}')
                          AND person_id in  (#{(params[:ids].blank? ? -1 : params[:ids])})").collect { |x| x.person_id }

    when "hiv indicators"
     indicator = Core::Concept.find_by_name(params[:indicator]).concept_id

     patients = Core::Observation.find_by_sql("SELECT DISTINCT m.person_id, m.value_numeric FROM obs m
                                                   WHERE person_id in  (#{(params[:ids].blank? ? -1 : params[:ids])}) AND
                                                   obs_datetime = (SELECT MAX(obs_datetime) FROM obs
                                                   WHERE person_id = m.person_id AND voided = 0 AND
                                                   obs_datetime <= '#{params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')}' AND
                                                   concept_id = #{indicator} ) AND concept_id = #{indicator} AND
                                                   m.value_numeric BETWEEN #{params[:min]} AND #{params[:max]} ").collect { |x| x.person_id }
    when "missing hiv indicators"
         indicator = Core::Concept.find_by_name(params[:indicator]).concept_id
         patients = Core::Person.find_by_sql("SELECT person_id FROM person WHERE person_id NOT IN
                          (SELECT DISTINCT person_id FROM obs WHERE concept_id = #{indicator}
                          AND voided = 0 AND obs_datetime <= '#{params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')}')
                          AND person_id in  (#{(params[:ids].blank? ? -1 : params[:ids])})").collect { |x| x.person_id }
    when "controlled bp"
     sbp_concept = Core::Concept.find_by_name('Systolic blood pressure').id
     dbp_concept = Core::Concept.find_by_name('Diastolic blood pressure').id

     patients = Core::Observation.find_by_sql("SELECT DISTINCT o.person_id, (SELECT MAX(obs_datetime) FROM obs
                                         WHERE person_id = o.person_id AND voided = 0 AND
                                         obs_datetime BETWEEN '#{params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')}'
                                         AND '#{params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')}' AND
                                         concept_id in (#{dbp_concept},#{sbp_concept}) ) AS max_date,
                                        (SELECT COALESCE(value_numeric,0) FROM obs WHERE obs_datetime = max_date
                                        AND concept_id = #{sbp_concept} AND person_id = o.person_id LIMIT 1) AS SBP,
                                        (SELECT COALESCE(value_numeric,0) FROM obs WHERE obs_datetime = max_date
                                        AND concept_id = #{dbp_concept} AND person_id = o.person_id LIMIT 1) AS DBP
                                        FROM obs as o WHERE o.person_id in  (#{(params[:ids].blank? ? -1 : params[:ids])})
                                        HAVING SBP BETWEEN #{params[:start_sbp]} AND #{params[:end_sbp]} AND DBP BETWEEN
                                        #{params[:start_dbp]} AND #{params[:end_dbp]}").collect { |x| x.person_id }
   end

   render :json => patients.to_json
  end

  def median(array)
   return 0 unless !array.blank?
   sorted = array.sort
   len = sorted.length
   return (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end
end
