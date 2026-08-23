class AddCreditCardDetailsToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :annual_fee, :decimal, precision: 8, scale: 2
    add_column :accounts, :perks, :text
    add_column :accounts, :renewal_on, :date
  end
end
