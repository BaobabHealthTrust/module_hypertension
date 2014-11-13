class DrugController < ApplicationController
  def drug_sets
    @user = User.find(session[:user_id] || params[:user_id])
    @sets = GeneralSet.all(:order => ["date_updated DESC"],
      :conditions => ["status = 'active'"]) +
      GeneralSet.all(:order => ["date_updated DESC"],
      :conditions => ["status = 'inactive'"])

    #raise @sets.to_yaml
    @set_name_ids_map = {}
    @set_desc_ids_map = {}
    @status = {}
    @drug_sets = {}
    @keys = []

    @sets.each{|set|

      @set_name_ids_map[set.set_id] = set.name
      @set_desc_ids_map[set.set_id] = set.description
      @status[set.set_id] = set.status
      @drug_sets[set.set_id] = set.drug_sets
      @keys << set.set_id
    }

    #render :layout => "general"
  end

  def void_set

    if params[:drug_set_id]
      drug_set = DrugSet.find(params[:drug_set_id])
      drug_set.void
    end

  end

  def add_drug_set

    already_selected = DrugSet.find_all_by_set_id(params[:set_id]).collect{|d| d.drug_inventory_id} rescue []
    already_selected = [-1] if already_selected.blank?
    @drugs = [["", ""]] + Drug.all(:conditions => ["drug_id NOT IN (?)",
        already_selected]).collect{|drug| [drug.name, drug.id]}

    @frequencies = ["", "Once a day (OD)", "Twice a day (BD)", "Three a day (TDS)",
      "Four times a day (QID)", "Five times a day (5X/D)", "Six times a day (Q4HRS)",
      "In the morning (QAM)", "Once a day at noon (QNOON)", "In the evening (QPM)",
      "Once a day at night (QHS)", "Every other day (QOD)",
      "Once a week (QWK)", "Once a month", "Twice a month"]
  end

  def create_drug_set

    d = (session[:datetime].to_date rescue Date.today)
    t = Time.now
    session_date = DateTime.new(d.year, d.month, d.day, t.hour, t.min, t.sec)

    set_id = params[:set_id]

    if params[:name]

      set = GeneralSet.new(:name => params[:name],
        :description => params[:description],
        :status => "active",
        :date_created => session_date,
        :date_updated => session_date,
        :creator => session[:user_id]
      )
      set.save!
      set_id = set.set_id
    end

    drug_set = DrugSet.new(:drug_inventory_id => params[:drug].to_i,
      :set_id => set_id.to_i,
      :frequency => params[:frequency],
      :duration => params[:duration].to_i,
      :dose => params[:strength],
      :date_created => session_date,
      :date_updated => session_date,
      :creator => params[:user_id]
    )
    drug_set.save!
    GeneralSet.find(set_id).update_attributes(:date_updated => session_date)

    redirect_to "/drug/drug_sets?user_id=#{params[:user_id]}&patient_id=#{params[:patient_id]}"
  end

  def deactivate

    d = (session[:datetime].to_date rescue Date.today)
    t = Time.now
    session_date = DateTime.new(d.year, d.month, d.day, t.hour, t.min, t.sec)

    s = GeneralSet.find(params[:set_id])
    s.deactivate(session_date) if !s.blank?

    render :text => "OK".to_json
  end

  def activate

    d = (session[:datetime].to_date rescue Date.today)
    t = Time.now
    session_date = DateTime.new(d.year, d.month, d.day, t.hour, t.min, t.sec)

    s = GeneralSet.find(params[:set_id])
    s.activate(session_date) if !s.blank?

    render :text => "OK".to_json
  end

  def block

    d = (session[:datetime].to_date rescue Date.today)
    t = Time.now
    session_date = DateTime.new(d.year, d.month, d.day, t.hour, t.min, t.sec)

    s = GeneralSet.find(params[:set_id])
    s.block(session_date) if !s.blank?
    render :text => 'ok'.to_json
  end
end
