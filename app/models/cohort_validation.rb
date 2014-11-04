class CohortValidation
    
	attr_accessor :cohort_object

	def initialize(cohort_obj)

		self.cohort_object = cohort_obj	
	end

	def get_all_differences
	 
	 #This code runs all methods that start with 'validate_' 
	 #And returns a hash of all return values from such methods
	 #By Kenneth Kapundi	 

		differences = {}
		(self.class.instance_methods(false) - Object.methods).each do |method|
			next if !method.match(/^validate\_/) 
			validation = method.sub(/^validate\_/, "").humanize
			differences[validation] = self.send(method) unless validation.blank?
		end
		
		return differences.delete_if{|key, val| val.blank?}
	end
	
	def feed_values(rule, val_arr)
		#This method takes an expression and replaces the curly 
		#brackets with values from the val_arr array based on position.
		#By Kenneth Kapundi
		expr = rule.expr
		return nil if expr.scan(/\{\w+\}/).length != val_arr.length
		return [rule.desc, eval(val_arr.inject(expr){|out_str, val| val = val.blank? ? [] : val; out_str = out_str.sub(/\{\w+\}/, "#{val.length}"); out_str})]
	end
	
	def validate_new_total_male_plus_total_pregnant_plus_total_nonpregnant_equals_total_registered
	  
	  # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate Newly (registered males + 
    #                               registered females (pregnant) + 
    #                               registered females (non -pregnant)) =
    #                               total registered  
    # Amendments  :

	  validation_rule = ValidationRule.find_by_expr('{new_total_reg} == {new_males} + {new_non_preg} + {new_preg_all_age}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Newly total registered'],
              self.cohort_object['Newly registered male'],
              self.cohort_object['Newly registered women (non-pregnant)'], 
              self.cohort_object['Newly registered women (pregnant)']
                ]
         
    return self.feed_values(validation_rule, values)
	end
	
	def validate_cumulative_total_male_plus_total_pregnant_plus_total_nonpregnant_equals_total_registered
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate cumulative (registered males + 
    #                                   registered females (pregnant) + 
    #                                   registered females (non -pregnant)) =
    #                                   total registered  
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_total_reg} == {cum_males} + {cum_non_preg} + {cum_preg_all_age}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered'],
                self.cohort_object['Total registered male'],
                self.cohort_object['Total registered women (non-pregnant)'], 
                self.cohort_object['Total registered women (pregnant)']
            ]
    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_total_registered
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate Total Registered (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_total_reg}>={new_total_reg}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered'],
              self.cohort_object['Newly total registered']
                ]

    return self.feed_values(validation_rule, values)
    
  end
  
  def validate_cumulative_and_new_patients_initiated_first_time
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate patients initiated first time on ART (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_ft}>={new_ft}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Patients initiated on ART'],
              self.cohort_object['Patients initiated on ART']
                ]

    return self.feed_values(validation_rule, values)
  end
	
	def validate_cumulative_and_new_patients_reinitiated
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate Patients reinitiated on ART (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_re}>={new_re}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Patients reinitiated on ART'],
              self.cohort_object['Patients reinitiated on ART']
                ]

    return self.feed_values(validation_rule, values)
  end  
  
  def validate_cumulative_and_new_transferedin_on_art
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate Patients transfered in on ART (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_ti}>={new_ti}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total transferred in patients'],
              self.cohort_object['Newly transferred in patients']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_registered_males
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate Registered Males  (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_males}>={new_males}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered male'],
              self.cohort_object['Newly registered male']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_non_pregnant_females
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate non pregnant females  (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_non_preg}>={new_non_preg}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered women (non-pregnant)'],
              self.cohort_object['Newly registered women (non-pregnant)']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_pregnant_females
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate pregnant females  (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_preg_all_age}>={new_preg_all_age}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered women (pregnant)'],
              self.cohort_object['Newly registered women (pregnant)']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_children_below_24_months
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate children below 24 months (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_a}>={new_a}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered infants'],
              self.cohort_object['Newly registered infants']
                ]

    return self.feed_values(validation_rule, values)
  end 
  
  def validate_cumulative_and_new_children_between_24_months_and_14_years
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate children between 24 months and 14 years (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_b}>={new_b}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered children'],
              self.cohort_object['Newly registered children']
                ]

    return self.feed_values(validation_rule, values)
  end 
  
  def validate_cumulative_and_new_adults
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate adults (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_c}>={new_c}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered adults'],
              self.cohort_object['Newly registered adults']
                ]

    return self.feed_values(validation_rule, values)
  end 
  
  def validate_cumulative_and_new_unknown_age
    
    # Developer   : Precious Bondwe
    # Date        : 25/02/2014
    # Purpose     : Validate unknown age (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_unk_age}>={new_unk_age}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Unknown age'],
              self.cohort_object['Newly Unknown age']
                ]

    return self.feed_values(validation_rule, values)
  end 

  def validate_kaposis_sarcoma_less_than_total_registered_in_quarter
		#This method checks that cases of kaposis sarcoma are less than total registered in quarter	
		#By Kenneth Kapundi
		
		validation_rule = ValidationRule.find_by_expr("{newly_reg} >= {ks}")
		return nil if validation_rule.blank?
				
		values = [self.cohort_object['Newly total registered'],
              self.cohort_object['Kaposis Sarcoma']    ]
		return self.feed_values(validation_rule, values)		
	end
	
	def validate_cumulative_kaposis_sarcoma_less_than_total_ever_registered
		#This method checks that all cases of kaposis sarcoma are less than cumulative total registered	
		#By Kenneth Kapundi
		
		validation_rule = ValidationRule.find_by_expr("{cum_total_reg} >= {total_ks}")
		return nil if validation_rule.blank?
				
		values = [self.cohort_object['Total registered'],
      self.cohort_object['Total Kaposis Sarcoma']]
		return self.feed_values(validation_rule, values)		
	end
	
	def validate_all_outcomes_equal_to_cumulative_total_registered
		#This method checks that outcome totals dont exceed total registered	
		#By Kenneth Kapundi
		
		validation_rule = ValidationRule.find_by_expr("{cum_total_reg} == {died_total} + {total_on_art} + {defaulted} + {stopped} + {transfered} + {unknown_outcome}")
		return nil if validation_rule.blank?
				
		values = [self.cohort_object['Total registered'],
				 			self.cohort_object['Died total'],
				 			self.cohort_object['Total alive and on ART'],
				 			self.cohort_object['Defaulted'],
				 			self.cohort_object['Stopped taking ARVs'],
				 			self.cohort_object['Transferred out'],
				 			self.cohort_object['Unknown outcomes']
				 			]			 					
		return self.feed_values(validation_rule, values)		
	end

	def validate_sum_of_tb_equal_total_alive_and_on_ART
		#Task 59
		#Sum of tb = total alive and on ART

		validation_rule = ValidationRule.find_by_desc("TB not suspected, TB suspected, TB confirmed not yet/currently not on TB treatment, TB confirmed on TB treatment, and Unknown TB status should add up to Total alive and on ART")

		return nil if validation_rule.blank?

		values = [self.cohort_object['Total alive and on ART'],
				 			self.cohort_object['TB not suspected'],
				 			self.cohort_object['TB suspected'],
				 			self.cohort_object['TB confirmed not treatment'],
				 			self.cohort_object['TB confirmed on treatment'],
				 			self.cohort_object['TB Unknown']
				 			]
		return self.feed_values(validation_rule, values)
	end	
	
	def validate_cumulative_and_new_presumed_severe_hiv_in_infants
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Reason for Starting of presumed severe HIV in infants (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_pres_hiv}>={new_pres_hiv}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Presumed severe HIV disease in infants'],
              self.cohort_object['Presumed severe HIV disease in infants']
                ]

    return self.feed_values(validation_rule, values)
  end

  def validate_cumulative_and_new_confirmed_hiv_infection_in_infants
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Reason for Starting of presumed severe confirmed HIV infection in infants (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_conf_hiv}>={new_conf_hiv}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Confirmed HIV infection in infants (PCR)'],
              self.cohort_object['Confirmed HIV infection in infants (PCR)']
                ]
    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_pregnant_women
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Reason for Starting of pregnant women (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_preg}>={new_preg}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Patient pregnant'],
              self.cohort_object['Patient pregnant']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_breastfeeding_mothers
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Reason for Starting of breastfeeding mothers (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_breastfeed}>={new_breastfeed}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Patient breastfeeding'],
              self.cohort_object['Patient breastfeeding']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_WHO_stage_1_or_2_cd4_count_below_threshhold
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Reason for Starting of WHO stage 1 or 2 with cd4 count below threshhold (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_who_1_2}>={new_who_1_2}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total WHO stage 1 or 2, CD4 below threshold'],
              self.cohort_object['WHO stage 1 or 2, CD4 below threshold']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_WHO_stage_2_total_lymphocytes
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Reason for Starting of WHO stage 2 total lymphocytes (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_who_2}>={new_who_2}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total WHO stage 2, total lymphocytes'],
              self.cohort_object['WHO stage 2, total lymphocytes']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_WHO_stage_3
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Reason for Starting of WHO stage 3 (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_who_3}>={new_who_3}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total WHO stage 3'],
              self.cohort_object['WHO stage 3']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_WHO_stage_4
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Reason for Starting of WHO stage 4 (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_who_4}>={new_who_4}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total WHO stage 4'],
              self.cohort_object['WHO stage 4']
                ]

    return self.feed_values(validation_rule, values)
  end

   def validate_cumulative_and_new_unknown_reason
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Reason for Starting of Unknown reason (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_other_reason}>={new_other_reason}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Unknown reason'],
              self.cohort_object['Unknown reason']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_TB_within_last_2_years
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Stage Defining Conditions of TB within last 2 years (Cumulative >= New)
    # Amendments  : 

   
    validation_rule = ValidationRule.find_by_expr('{cum_tb_w2yrs}>={new_tb_w2yrs}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['tb_with_the_last_2yrs'],
              self.cohort_object['total_tb_with_the_last_2yrs']
                ]
    return self.feed_values(validation_rule, values)
  end
  
  def validate_adherence_sum_zero_to_six_and_seven_plus_needs_to_equal_total_alive_and_on_art
    validation_rule = ValidationRule.find_by_desc("Patients with 0-6 doses missed at their last visit(before end of quarter evaluated), and Patients with 7+ doses missed at their last visit(before end of quarter evaluated) should add up to Total alive and on ART")
    return nil if validation_rule.blank?
    values = [self.cohort_object['Total alive and on ART'],
				 			self.cohort_object['Patients with 0 - 6 doses missed at their last visit'],
				 			self.cohort_object['Patients with 7+ doses missed at their last visit']
				 			]
		return self.feed_values(validation_rule, values)
  end

def validate_sum_of_stage_defining_conditions_needs_to_equal_total_registered
     validation_rule = ValidationRule.find_by_desc("[CUMULATIVE] No TB, TB within the last 2 years, Current episode of TB, and Kaposis Sarcoma should add up to Total registered")
     values = [self.cohort_object['Total registered'],
				 			self.cohort_object['Total No TB'],
				 			self.cohort_object['tb_with_the_last_2yrs'],
				 			self.cohort_object['total_tb_with_the_last_2yrs']
				 			]
		return self.feed_values(validation_rule, values)

  end

  def validate_sum_of_all_regimens_should_equal_to_total_alive_and_on_art
    #validating all regimens should add up to total_alive_and_on_art

    validation_rule = ValidationRule.find_by_expr("{total_on_art} == {n0a} + {n0p} + {n1a} + {n1p} + {n2a} + {n2p} + {n3a} + {n3p} + {n4a} + {n4p} + {n5a} + {n6a} + {n7a} + {n8a} + {n9p} + {non_std}")
    return nil if validation_rule.blank? ||  self.cohort_object['Regimens'].blank?

    values = [self.cohort_object['Total alive and on ART'] ||= [],
              self.cohort_object['Regimens']['1A'] ||= [],
              self.cohort_object['Regimens']['1P'] ||= [],
              self.cohort_object['Regimens']['2A'] ||= [],
              self.cohort_object['Regimens']['2P'] ||= [],
              self.cohort_object['Regimens']['3A'] ||= [],
              self.cohort_object['Regimens']['3P'] ||= [],
              self.cohort_object['Regimens']['4A'] ||= [],
              self.cohort_object['Regimens']['4P'] ||= [],
              self.cohort_object['Regimens']['5A'] ||= [],
              self.cohort_object['Regimens']['6A'] ||= [],
              self.cohort_object['Regimens']['7A'] ||= [],
              self.cohort_object['Regimens']['8A'] ||= [],
              self.cohort_object['Regimens']['9P'] ||= [],
              self.cohort_object['Regimens']['0A'] ||= [],
              self.cohort_object['Regimens']['0P'] ||= [],              
              self.cohort_object['non-standard'] ||= []]

   return self.feed_values(validation_rule, values)
  end

  def validate_quartely_sum_of_all_ages_should_equal_to_quartely_total_registered
    #validating quartery sum of infants+children+adults+unknow_age
    #should equal to quartly total registered

    validation_rule = ValidationRule.find_by_expr("{new_total_reg} == {new_a} + {new_b} + {new_c} + {new_unk_age}")
    return nil if validation_rule.blank?

    values = [self.cohort_object['Newly total registered'] ||= [],
              self.cohort_object['Newly registered infants'] ||= [],
              self.cohort_object['Newly registered children'] ||= [],
              self.cohort_object['Newly registered adults'] ||= [],
              self.cohort_object['New Unknown age'] ||= []]

    return self.feed_values(validation_rule, values)
  end

  def validate_cumulative_and_new_current_episode_of_TB
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Current Episode of TB (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_current_tb}>={new_current_tb}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Current episode of TB'],
              self.cohort_object['Current episode of TB']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_kaposis_sarcoma
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Stage Defining Conditions of Kaposis Sarcoma (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_ks}>={new_ks}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total Kaposis Sarcoma'],
              self.cohort_object['Kaposis Sarcoma']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_no_TB
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Stage Defining Conditions of no TB (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_no_tb}>={new_no_tb}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total No TB'],
              self.cohort_object['No TB']
                ]

    return self.feed_values(validation_rule, values)
  end
  
  def validate_cumulative_and_new_Children_12_to_23_months
    
    # Developer   : Precious Bondwe
    # Date        : 26/02/2014
    # Purpose     : Validate Reason for Starting of Children 12 - 23 months (Cumulative >= New)
    # Amendments  :

   
    validation_rule = ValidationRule.find_by_expr('{cum_children}>={new_children}')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total HIV infected'],
              self.cohort_object['HIV infected']
                ]

    return self.feed_values(validation_rule, values)
  end

  def validate_cumulative_sum_all_ages_should_equal_to_cumulative_total_registered
    #validating cumulative sum of infants+children+adults+unknow_age
    #should equal to cumulative total registered

    validation_rule = ValidationRule.find_by_expr("{cum_total_reg} == {cum_a} + {cum_b} + {cum_c} + {cum_unk_age}")
    return nil if validation_rule.blank?

    values = [self.cohort_object['Total registered'] ||= [],
              self.cohort_object['Total registered infants'] ||= [],
              self.cohort_object['Total registered children'] ||= [],
              self.cohort_object['Total registered adults'] ||= [],
              self.cohort_object['Total Unknown age'] ||= []]

    return self.feed_values(validation_rule, values)
  end

	def validate_sum_of_reason_starting_ART_equal_total_registered
		#Task 51
		#sum of reason starting ART equal to total registered

		validation_rule = ValidationRule.find_by_desc("[CUMULATIVE] Presumed severe HIV disease in infants, Confirmed HIV infection in infants (PCR), WHO stage 1 or 2, CD4 below threshold, Children 12-23 mths, Breastfeeding mothers, Pregnant women, WHO stage 3, WHO stage 4, and Unknown/other reason outside ")
		return nil if validation_rule.blank?

		values = [self.cohort_object['Total registered'],
							self.cohort_object['Total Presumed severe HIV disease in infants'],
							self.cohort_object['Total Confirmed HIV infection in infants (PCR)'],
							self.cohort_object['Total WHO stage 1 or 2, CD4 below threshold'],
							self.cohort_object['Total WHO stage 2, total lymphocytes'],
							self.cohort_object['Total registered children'],
							self.cohort_object['Total Patient breastfeeding'],
							self.cohort_object['Total Patient pregnant'],
							self.cohort_object['Total WHO stage 3'],
							self.cohort_object['Total WHO stage 4'],
							self.cohort_object['Total Unknown reason']
				 		 ]
		return self.feed_values(validation_rule, values)
	end
	
	def validate_cumulative_died_intervals_sum_up_to_died_total
		#This method checks that the sum of figures in died intervals should equal died total	
		#By Kenneth Kapundi
		
		validation_rule = ValidationRule.find_by_desc("Died within the 1st month after ART initiation, Died within the 2nd month after ART initiation, Died within the 3rd month after ART initiation, and Died after the end of the 3rd month after ART initiation should add up to Died total")
		
		return nil if validation_rule.blank?
				
		values = [self.cohort_object['Died total'],
				 			self.cohort_object['Died within the 1st month after ART initiation'],
				 			self.cohort_object['Died within the 2nd month after ART initiation'],
				 			self.cohort_object['Died within the 3rd month after ART initiation'],
				 			self.cohort_object['Died after the end of the 3rd month after ART initiation']
				 			]			 					
		return self.feed_values(validation_rule, values)		
	end

 def validate_total_registered_is_sum_of_intitiated_reinitiated_and_transfer_in
    #Task 48
   
    validation_rule = ValidationRule.find_by_desc('[QUARTER] FT: Patients initiated on ART first time, Re: Patients re-initiated on ART, and TI: Patients transfered in on ART should add up to Total registered')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Newly total registered'],
              self.cohort_object['Patients initiated on ART'],
              self.cohort_object['Patients reinitiated on ART'],
							self.cohort_object['Newly transferred in patients']
                ]

    return self.feed_values(validation_rule, values)
  end

  def validate_cumulative_total_registered_is_sum_of_intitiated_reinitiated_and_transfer_in
    #Task 48
   
    validation_rule = ValidationRule.find_by_desc('[CUMULATIVE] FT: Patients initiated on ART first time, Re: Patients re-initiated on ART, and TI: Patients transfered in on ART should add up to Total registered')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total registered'],
              self.cohort_object['Total Patients initiated on ART'],
              self.cohort_object['Total Patients reinitiated on ART'],
							self.cohort_object['Total transferred in patients']
                ]

    return self.feed_values(validation_rule, values)
  end

  def validate_total_alive_and_side_effects
    #Task 57
   
    validation_rule = ValidationRule.find_by_desc('Total patients with side effects should not exceed Total alive and on ART')
    return nil if validation_rule.blank?
        
    values = [self.cohort_object['Total alive and on ART'],
              self.cohort_object['Total patients with side effects']
                ]

    return self.feed_values(validation_rule, values)
  end    

  def validate_total_registered_minus_sum_of_outcomes_equal_total_alive_and_on_art
    #validate total registered minus all outcomes should equal to total alive and on art

    validation_rule = ValidationRule.find_by_desc('Total registered minus Died total, Defaulted (more than 2 months overdue after expected to have run out of ARVs), Stopped taking ARVs (clinician or patient own decision last known alive), Transfered and Unknown outcome should equal to Total alive and on art')

    return nil if validation_rule.blank?

    values = [self.cohort_object['Total alive and on ART'],
              self.cohort_object['Total registered'],
              self.cohort_object['Died total'],
              self.cohort_object['Defaulted'],
              self.cohort_object['Stopped taking ARVs'],
              self.cohort_object['Transferred out'],
              self.cohort_object['Unknown outcomes']
                ]

    return self.feed_values(validation_rule, values)
  end

end

