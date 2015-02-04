module Core
  class Concept < ActiveRecord::Base
    set_table_name :concept
    set_primary_key :concept_id
    include Core::Openmrs

    belongs_to :concept_class, :class_name => 'Core::ConceptClass', :conditions => {:retired => 0}
    belongs_to :concept_datatype, :class_name => 'Core::ConceptDatatype', :conditions => {:retired => 0}
    has_one :concept_numeric, :class_name => 'Core::ConceptNumeric', :foreign_key => :concept_id, :dependent => :destroy
    #has_one :name, :class_name => 'ConceptName'
    has_many :answer_concept_names, :class_name => 'Core::ConceptName', :conditions => {:voided => 0}
    has_many :concept_names, :class_name => 'Core::ConceptName', :conditions => {:voided => 0}
    has_many :concept_maps, :class_name => 'Core::ConceptMap' # no default scope
    has_many :concept_sets, :class_name => 'Core::ConceptSet' # no default scope
    has_many :concept_answers, :class_name => 'Core::ConceptAnswer' do # no default scope
      def limit(search_string)
        return self if search_string.blank?
        map { |concept_answer|
          concept_answer if concept_answer.name.match(search_string)
        }.compact
      end
    end
    has_many :drugs, :conditions => {:retired => 0}
    has_many :concept_members, :class_name => 'ConceptSet', :foreign_key => :concept_set

    def self.find_by_name(concept_name)
      Core::Concept.find(:first, :joins => 'INNER JOIN concept_name on concept_name.concept_id = concept.concept_id', :conditions => ["concept.retired = 0 AND concept_name.voided = 0 AND concept_name.name =?", "#{concept_name}"])
    end

    def shortname
      name = self.concept_names.typed('SHORT').first.name rescue nil
      return name unless name.blank?
      return self.concept_names.first.name rescue nil
    end

    def fullname
      name = self.concept_names.typed('FULLY_SPECIFIED').first.name rescue nil
      return name unless name.blank?
      return self.concept_names.first.name rescue nil
    end
  end
end