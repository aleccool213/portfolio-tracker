class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name
      t.string :institution
      t.string :kind

      t.timestamps
    end
  end
end
