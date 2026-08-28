class ValueEntriesController < ApplicationController
  # One row per product we track a value for. Credit cards are intentionally
  # value-less (we track perks, not balances), so they exclude themselves.
  def show
    @month = Date.current.beginning_of_month
    @products = trackable_products
    @current_values = AccountValue.where(account_id: @products.map(&:id), recorded_on: @month)
                                  .index_by(&:account_id)
  end

  # Upsert one AccountValue per submitted product for the current month.
  # Blank fields are skipped, so you can enter accounts a few at a time without
  # wiping the ones you left alone.
  def create
    month = Date.current.beginning_of_month
    products_by_id = trackable_products.index_by(&:id)

    AccountValue.transaction do
      submitted_values.each do |account_id, amount|
        next if amount.blank?

        product = products_by_id[account_id.to_i]
        next if product.nil?

        product.record_amount(month, amount)
      end
    end

    redirect_to root_path, notice: "Saved this month's values 🎉"
  end

  private

  def trackable_products
    @trackable_products ||= Products.wrap_all(Account.order(:kind, :name)).select(&:trackable?)
  end

  def submitted_values
    values = params[:values]
    return {} if values.blank?

    values.to_unsafe_h
  end
end
