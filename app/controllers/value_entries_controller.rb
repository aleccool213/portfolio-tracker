class ValueEntriesController < ApplicationController
  # One row per account we track a value for. Credit cards are intentionally
  # value-less (we track perks, not balances), so they're excluded here.
  def show
    @month = Date.current.beginning_of_month
    @accounts = trackable_accounts
    @current_values = AccountValue.where(account: @accounts, recorded_on: @month)
                                  .index_by(&:account_id)
  end

  # Upsert one AccountValue per submitted account for the current month.
  # Blank fields are skipped, so you can enter accounts a few at a time without
  # wiping the ones you left alone.
  def create
    month = Date.current.beginning_of_month
    allowed_ids = trackable_accounts.pluck(:id).to_set

    AccountValue.transaction do
      submitted_values.each do |account_id, amount|
        next if amount.blank?
        next unless allowed_ids.include?(account_id.to_i)

        value = AccountValue.find_or_initialize_by(account_id: account_id, recorded_on: month)
        value.update!(amount: amount)
      end
    end

    redirect_to root_path, notice: "Saved this month's values 🎉"
  end

  private

  def trackable_accounts
    Account.where.not(kind: "credit_card").order(:kind, :name)
  end

  def submitted_values
    values = params[:values]
    return {} if values.blank?

    values.to_unsafe_h
  end
end
