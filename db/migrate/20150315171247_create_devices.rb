class CreateDevices < ActiveRecord::Migration
  def change
    create_table :devices do |t|
      t.string :core_id
      t.string :model_id
    end
  end
end
