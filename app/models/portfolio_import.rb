# Upserts accounts and monthly values from format-agnostic PortfolioRows.
# Invalid rows fail the whole import (transaction rolls back).
class PortfolioImport
  Result = Data.define(:accounts_created, :accounts_updated, :values_upserted, :errors) do
    def success?
      errors.empty?
    end

    def summary
      parts = []
      parts << "#{accounts_created} account#{'s' if accounts_created != 1} created" if accounts_created.positive?
      parts << "#{accounts_updated} account#{'s' if accounts_updated != 1} updated" if accounts_updated.positive?
      parts << "#{values_upserted} value#{'s' if values_upserted != 1} saved" if values_upserted.positive?
      parts.empty? ? "Nothing imported" : parts.join(", ")
    end
  end

  def initialize(rows)
    @rows = rows
    @accounts_created = 0
    @accounts_updated = 0
    @values_upserted = 0
    @errors = []
    @seen_account_ids = Set.new
  end

  def call
    Account.transaction do
      @rows.each { |row| import_row(row) }
      raise ActiveRecord::Rollback if @errors.any?
    end

    if @errors.any?
      @accounts_created = 0
      @accounts_updated = 0
      @values_upserted = 0
    end

    Result.new(
      accounts_created: @accounts_created,
      accounts_updated: @accounts_updated,
      values_upserted: @values_upserted,
      errors: @errors
    )
  end

  private

  def import_row(row)
    name = row.name.to_s.strip.presence
    if name.blank?
      error(row, "name is required")
      return
    end

    account = find_account(row)
    if account
      assign_account_attributes(account, row, name)
      account.save!
      note_account(account, created: false)
    else
      if kind_for(row).blank?
        error(row, "kind is required when creating a new account")
        return
      end
      unless Account::KINDS.include?(kind_for(row))
        error(row, "kind must be one of #{Account::KINDS.join(', ')}")
        return
      end

      account = Account.create!(account_attributes(row, name))
      note_account(account, created: true)
    end

    apply_value(account, row)
  rescue ActiveRecord::RecordInvalid => e
    error(row, e.record.errors.full_messages.to_sentence)
  rescue ArgumentError, TypeError => e
    error(row, e.message)
  end

  def find_account(row)
    if row.account_id.present?
      account = Account.find_by(id: row.account_id)
      return account if account
    end

    Account.find_by(name: row.name.to_s.strip.presence, institution: row.institution.presence)
  end

  def kind_for(row)
    row.kind.to_s.strip.downcase.presence
  end

  def account_attributes(row, name)
    {
      name: name,
      institution: row.institution.presence,
      kind: kind_for(row),
      interest_rate: row.interest_rate,
      term_months: row.term_months,
      original_principal: row.original_principal
    }
  end

  def assign_account_attributes(account, row, name)
    account.name = name
    account.institution = row.institution.presence
    account.kind = kind_for(row) if kind_for(row)
    account.interest_rate = row.interest_rate unless row.interest_rate.nil?
    account.term_months = row.term_months unless row.term_months.nil?
    account.original_principal = row.original_principal unless row.original_principal.nil?
  end

  def apply_value(account, row)
    return if row.value_id.blank? && row.recorded_on.blank? && row.amount.blank?

    if (row.recorded_on.blank? || row.amount.blank?) && row.value_id.blank?
      error(row, "recorded_on and amount must both be present to import a value")
      return
    end

    if account.kind == "credit_card" && (row.recorded_on.present? || row.amount.present?)
      error(row, "credit cards do not track balances — leave recorded_on and amount blank")
      return
    end

    return if account.kind == "credit_card"

    recorded_on = coerce_recorded_on(row)
    value = find_value(account, row, recorded_on)
    value.recorded_on = recorded_on if recorded_on
    value.amount = row.amount unless row.amount.nil?
    value.save!
    @values_upserted += 1
  end

  def find_value(account, row, recorded_on)
    if row.value_id.present?
      value = AccountValue.find_by(id: row.value_id)
      if value
        if value.account_id != account.id
          raise ArgumentError, "value_id belongs to a different account"
        end
        return value
      end
    end

    raise ArgumentError, "recorded_on is required when value_id is missing" if recorded_on.blank?

    AccountValue.find_or_initialize_by(account: account, recorded_on: recorded_on)
  end

  def coerce_recorded_on(row)
    return if row.recorded_on.blank?

    date = row.recorded_on.is_a?(Date) ? row.recorded_on : Date.parse(row.recorded_on.to_s)
    date.beginning_of_month
  end

  def error(row, message)
    prefix = row.origin.present? ? "#{row.origin}: " : ""
    @errors << "#{prefix}#{message}"
  end

  def note_account(account, created:)
    return if @seen_account_ids.include?(account.id)

    @seen_account_ids << account.id
    if created
      @accounts_created += 1
    else
      @accounts_updated += 1
    end
  end
end
