class UpdateReadingParams < ActiveRecord::Migration
  def change
    remove_column :readings, :min_spo2
    rename_column :readings, :mean_spo2, :spo2
    rename_column :readings, :mean_hr, :hr
  end
end
