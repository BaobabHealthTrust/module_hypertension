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

   unless params[:category].blank?
    case params[:category]
     when "gender"
      patients = Core::Person.find(:all, :conditions => ["person_id in (?) AND COALESCE(gender,'unknown') in (?)",
                                                         patients,params[:gender] ]).collect{ |x| x.person_id}
     when "age"
      patients = Core::Person.find_by_sql("SELECT person_id,
               COALESCE(((to_days('#{params[:end_date]}') - to_days(`person`.`birthdate`))/365.25),'unknown') AS age
               FROM person WHERE person_id in (#{patients.join(',')}) AND voided=0
               HAVING age BETWEEN '#{params[:start_age]}' AND '#{params[:end_age]}'")

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
                                         value_numeric BETWEEN '#{params[:start_bmi]}' AND '#{params[:end_bmi]}'")

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
                                        FROM obs as o HAVING SBP BETWEEN #{params[:start_sbp]} AND #{params[:end_sbp]}
                                        AND DBP BETWEEN #{params[:start_dbp]} AND #{params[:end_dbp]}")
    end

   end

   render :json => patients.to_json
  end

  def total_screened_by_outcome(start_date, end_date, outcome)

  end

  def total_screen_by_place_of_diagnosis(start_date, end_date, location)

  end

  def total_screened_by_bp_classification(start_date, end_date,classification)

  end

  def total_screened_by_diagnosis(start_date, end_date, diagnosis)

  end

  def median(array)
   return 0 unless !array.blank?
   sorted = array.sort
   len = sorted.length
   return (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end
end
