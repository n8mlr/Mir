class CreateResources < ActiveRecord::Migration
  def self.up
    create_table :resources do |t|
      t.string :filename, :null => false
      t.integer :size, :default => 0, :null => false
      t.string :checksum, :limit => 32
      t.datetime :last_modified
      t.datetime :add_date, :default => DateTime.now
      t.datetime :last_synchronized
      t.datetime :last_indexed_at
      t.boolean :is_directory, :default => false, :null => false
      t.boolean :in_progress, :default => false
      t.boolean :queued, :default => false
      t.integer :times_failed, :default => 0, :null => false
    end
    
    add_index :resources, :filename, :unique => true
    add_index :resources, :in_progress
    add_index :resources, :last_indexed_at
    add_index :resources, :queued
  end

  def self.down
    drop_table :resources
  end
end