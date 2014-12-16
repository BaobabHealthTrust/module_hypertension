module Core
  class Privilege < ActiveRecord::Base
    set_table_name "privilege"
    set_primary_key "privilege"
    include Core::Openmrs

    has_many :role_privileges, :class_name => 'Core::RolePrivilege', :foreign_key => :privilege, :dependent => :delete_all # no default scope
    has_many :roles, :class_name => 'Core::Role', :through => :role_privileges # no default scope

    # NOT USED
    def self.create_privileges_and_attach_to_roles
      Core::Privilege.find_all.each { |p| puts "Destroying #{p.privilege}"; p.destroy }
      tasks = Core::EncounterType.find(:all).collect { |e| e.name }
      tasks.delete("Barcode scan")
      tasks << "Enter past visit"
      tasks << "View reports"

      tasks.each { |task|
        puts "Adding task: #{task}"
        p = Core::Privilege.new
        p.privilege = task
        p.save
        Core::Role.find(:all).each { |role|
          rp = Core::RolePrivilege.new
          rp.role = role
          rp.privilege = p
          rp.save
        }
      }
    end

  end


### Original SQL Definition for privilege #### 
#   `privilege` varchar(50) NOT NULL default '',
#   `description` varchar(250) NOT NULL default '',
#   PRIMARY KEY  (`privilege_id`)
end