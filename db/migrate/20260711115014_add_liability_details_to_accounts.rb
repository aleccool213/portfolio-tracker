class AddLiabilityDetailsToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :interest_rate, :decimal, precision: 6, scale: 3
    add_column :accounts, :term_months, :integer
    add_column :accounts, :original_principal, :decimal, precision: 12, scale: 2
  end
end
