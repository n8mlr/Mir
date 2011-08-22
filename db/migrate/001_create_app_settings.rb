class CreateAppSettings < ActiveRecord::Migration
  def self.up
    create_table :app_settings do |t|
      t.string :name
      t.string :value
    end
    add_index :app_settings, :name
  end

  def self.down
    drop_table :app_settings
  end
end