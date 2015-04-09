class CreateReadings < ActiveRecord::Migration
  def change
    create_table :readings do |t|
      t.references :session
      t.float :spo2
      t.float :hr
      t.float :quality
      t.datetime :published_at
    end
  end
end
