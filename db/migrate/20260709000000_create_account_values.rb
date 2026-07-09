class CreateAccountValues < ActiveRecord::Migration[8.1]
  def change
    create_table :account_values do |t|
      t.references :account, null: false, foreign_key: true
      t.date :recorded_on, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false

      t.timestamps
    end

    add_index :account_values, [ :account_id, :recorded_on ], unique: true
  end
end
