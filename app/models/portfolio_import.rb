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
      parts << "#{accounts_updated} account#{'s' if accounts_updated != 1} matched" if accounts_updated.positive?
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

    institution = row.institution.presence
    kind = row.kind.to_s.strip.downcase.presence

    account = Account.find_by(name: name, institution: institution)

    if account.nil?
      if kind.blank?
        error(row, "kind is required when creating a new account")
        return
      end
      unless Account::KINDS.include?(kind)
        error(row, "kind must be one of #{Account::KINDS.join(', ')}")
        return
      end

      account = Account.create!(
        name: name,
        institution: institution,
        kind: kind,
        interest_rate: row.interest_rate,
        term_months: row.term_months,
        original_principal: row.original_principal
      )
      note_account(account, created: true)
    else
      note_account(account, created: false)
    end

    return if row.recorded_on.blank? && row.amount.blank?

    if row.recorded_on.blank? || row.amount.blank?
      error(row, "recorded_on and amount must both be present to import a value")
      return
    end

    if account.kind == "credit_card"
      error(row, "credit cards do not track balances — leave recorded_on and amount blank")
      return
    end

    recorded_on = row.recorded_on.is_a?(Date) ? row.recorded_on : Date.parse(row.recorded_on.to_s)
    value = AccountValue.find_or_initialize_by(account: account, recorded_on: recorded_on.beginning_of_month)
    value.amount = row.amount
    value.save!
    @values_upserted += 1
  rescue ActiveRecord::RecordInvalid => e
    error(row, e.record.errors.full_messages.to_sentence)
  rescue ArgumentError, TypeError => e
    error(row, e.message)
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
