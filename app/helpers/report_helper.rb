module ReportHelper
 def self.report_duration(report_type)
  reports = {'Demographic and Clinical' => ['monthly', 'demographic_and_clinical'],
             'Among those with Hypertension'=> ['monthly','among_those_with_hypertension'],
             'Alive and in care with diagnosed hypertension' => ['monthly','alive_and_in_care_report'],
             'Program Evaluation Data (Baseline)' => ['annual','program_evaluation_baseline'],
             'Program Evaluation Data (Followup)' => ['annual','program_evaluation_followup'],
             'Program Impact' => ['annual','program_impact_report']
  }

  return reports[report_type]
 end
end
