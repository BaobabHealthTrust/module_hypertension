module Core
  module Openmrs
    module ClassMethods
      def assign_scopes
        col_names = self.columns.map(&:name)
        self.default_scope :conditions => "#{self.table_name}.voided = 0" if col_names.include?("voided")
        self.default_scope :conditions => "#{self.table_name}.retired = 0" if col_names.include?("retired")
      end

      # We needed a way to break out of the default scope, so we introduce inactive
      def inactive(*args)
        col_names = self.columns.map(&:name)
        scope = {}
        scope = {:conditions => "#{self.table_name}.voided = 1"} if col_names.include?("voided")
        scope = {:conditions => "#{self.table_name}.retired = 1"} if col_names.include?("retired")
        with_scope({:find => scope}, :overwrite) do
          if ([:all, :first].include?(args.first))
            self.find(*args)
          else
            self.all(*args)
          end
        end
      end

      # Shortcut for  looking up OpenMRS models by name using symbols or name
      # e.g. Concept[:diagonis] instead of Concept.find_by_name('diagnosis')
      #      Location[:my_hospital] => Location.find_by_name('neno district hospital')
      def [](name)
        name = name.to_s.gsub('_', ' ')
        self.find_by_name(name)
      end

      # Include voided or retired records
      def find_with_voided(options)
        with_exclusive_scope { self.find(options) }
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
      base.assign_scopes
    end

    def before_save
      super
      self.changed_by = Core::User.current.id if self.attributes.has_key?("changed_by") and Core::User.current != nil
      self.date_changed = Time.now if self.attributes.has_key?("date_changed")
    end

    def before_create
      super

      if !Core::Person.migrated_datetime.to_s.empty?
        self.location_id = Core::Person.migrated_location if self.attributes.has_key?("location_id")
        self.creator = Core::Person.migrated_creator if self.attributes.has_key?("creator")

        self.creator = Core::User.first.id if self.attributes.has_key?("creator") and (self.creator.blank? ||
            self.creator == 0)and Core::User.first != nil and Core::User.current.nil?

        self.date_created = Core::Person.migrated_datetime if self.attributes.has_key?("date_created")
      else
        self.location_id = Core::Location.current_health_center.id if self.attributes.has_key?("location_id") and (self.location_id.blank? || self.location_id == 0) and Core::Location.current_health_center != nil
        self.creator = Core::User.current.id if self.attributes.has_key?("creator") and
            (self.creator.blank? || self.creator == 0)and Core::User.current != nil

        self.creator = Core::User.first.id if self.attributes.has_key?("creator") and (self.creator.blank? ||
            self.creator == 0)and Core::User.first != nil and Core::User.current.nil?

        self.date_created = Time.now if self.attributes.has_key?("date_created")
      end

      self.uuid = ActiveRecord::Base.connection.select_one("SELECT UUID() as uuid")['uuid'] if self.attributes.has_key?("uuid")
    end

    # Override this
    def after_void(reason = nil)
    end

    def void(reason = "Voided through #{(BART_VERSION rescue "Undefined")}", date_voided = Time.now,
             voided_by = (Core::User.current.user_id unless Core::User.current.nil?))
      unless voided?
        self.date_voided = date_voided
        self.voided = 1
        self.void_reason = reason
        self.voided_by = voided_by
        self.save
        self.after_void(reason)
      end
    end

    def voided?
      self.attributes.has_key?("voided") ? voided == 1 : raise("Model does not support voiding")
    end

    def add_location_obs
      obs = Core::Observation.new()
      obs.person_id = self.patient_id
      obs.encounter_id = self.id
      obs.concept_id = Core::ConceptName.find_by_name("WORKSTATION LOCATION").concept_id
      obs.value_text = Core::Location.current_location.name
      obs.obs_datetime = self.encounter_datetime
      obs.save
    end

  end
end