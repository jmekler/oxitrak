class CreateReadings < ActiveRecord::Migration
  def change
    create_table :readings do |t|
      t.references :device
      t.float :min_spo2
      t.float :mean_spo2
      t.float :mean_hr
      t.float :quality
      t.datetime :published_at
    end
  end
end
