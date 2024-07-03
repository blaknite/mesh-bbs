class CreateBulletins < ActiveRecord::Migration[7.1]
  def change
    create_table :bulletins do |table|
      table.string :from, null: false
      table.text :subject, null: false
      table.text :body, null: false
      table.timestamps
    end
  end
end
