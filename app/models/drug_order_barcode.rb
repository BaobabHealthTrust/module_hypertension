class DrugOrderBarcode < ActiveRecord::Base
  set_table_name "drug_order_barcodes"
  set_primary_key "drug_order_barcode_id"
  belongs_to :drug, :foreign_key => "drug_id"
end
