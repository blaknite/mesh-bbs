class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |table|
      table.string :from, null: false
      table.string :to, null: false
      table.text :subject, null: false
      table.text :body, null: false
      table.boolean :read, default: false
      table.timestamps
    end
  end
end
