class CreateSessions < ActiveRecord::Migration
  def change
    create_table :sessions do |t|
      t.references :device
      t.boolean :active, default: true
      t.datetime :started_at
      t.datetime :ended_at
    end
  end
end
