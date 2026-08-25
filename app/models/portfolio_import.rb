# Upserts accounts and monthly values from format-agnostic PortfolioRows.
# Invalid rows fail the whole import (transaction rolls back).
class PortfolioImport
  ACCOUNT_COMPARE_KEYS = %w[name institution kind interest_rate term_months original_principal].freeze

  # Outcome of #call after a write (or a rolled-back attempt).
  Result = Data.define(:accounts_created, :accounts_updated, :values_upserted, :errors) do
    def success?
      errors.empty?
    end

    # Flash-style line, e.g. "2 accounts created, 3 values saved".
    def summary
      parts = []
      parts << "#{accounts_created} account#{'s' if accounts_created != 1} created" if accounts_created.positive?
      parts << "#{accounts_updated} account#{'s' if accounts_updated != 1} updated" if accounts_updated.positive?
      parts << "#{values_upserted} value#{'s' if values_upserted != 1} saved" if values_upserted.positive?
      parts.empty? ? "Nothing imported" : parts.join(", ")
    end
  end

  # One CSV row as it would be applied: :create / :update / :keep / :none.
  # account_changes / value_changes are { "field" => [before, after] } on updates.
  Entry = Data.define(:row, :account_action, :value_action, :account_changes, :value_changes, :error) do
    def initialize(row:, account_action: nil, value_action: :none, account_changes: {}, value_changes: {}, error: nil)
      super
    end
  end

  # Dry-run of #call. success? is false when any row has an error (confirm hidden).
  Plan = Data.define(:entries, :errors) do
    def success?
      errors.empty?
    end

    # Preview headline, e.g. "1 account will be created · 2 values will be created".
    def summary
      usable = entries.reject { |entry| entry.error.present? }
      bits = [
        group_phrase(
          usable.count { |entry| entry.account_action == :create },
          usable.count { |entry| entry.account_action == :update },
          "account"
        ),
        group_phrase(
          usable.count { |entry| entry.value_action == :create },
          usable.count { |entry| entry.value_action == :update },
          "value"
        )
      ].compact
      bits.empty? ? "Nothing will change" : bits.join(" · ")
    end

    # "2 accounts will be created, 1 updated" — or nil when both counts are zero.
    def group_phrase(creates, updates, noun)
      return if creates.zero? && updates.zero?

      created = "#{creates} #{noun}#{'s' if creates != 1} will be created" if creates.positive?
      if updates.positive?
        updated = if creates.positive?
          "#{updates} updated"
        else
          "#{updates} #{noun}#{'s' if updates != 1} will be updated"
        end
      end
      [ created, updated ].compact.join(", ")
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

  # Classify each row as create / update / keep without writing.
  # Same matching rules as #call. Does not mutate persisted records.
  def preview
    @errors = []
    @pending_new_accounts = {}
    entries = @rows.map { |row| preview_row(row) }
    Plan.new(entries: entries, errors: @errors)
  end

  # Persist rows in a transaction. Any row error rolls the whole batch back.
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

  # Create or update one account, then upsert its value when the row has one.
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

  # Match account_id first, then (name, institution). Unknown ids fall through.
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

  # Attributes for Account.create! — includes liability fields even when blank.
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

  # Blank CSV cells leave the existing attribute alone (except name/institution).
  def assign_account_attributes(account, row, name)
    account.name = name
    account.institution = row.institution.presence
    account.kind = kind_for(row) if kind_for(row)
    account.interest_rate = row.interest_rate unless row.interest_rate.nil?
    account.term_months = row.term_months unless row.term_months.nil?
    account.original_principal = row.original_principal unless row.original_principal.nil?
  end

  # Upsert a monthly snapshot, or skip for account-only / credit-card rows.
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

  # Match value_id first (must belong to this account), then (account, recorded_on).
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

  # Snapshots always live on the 1st of the month.
  def coerce_recorded_on(row)
    return if row.recorded_on.blank?

    date = row.recorded_on.is_a?(Date) ? row.recorded_on : Date.parse(row.recorded_on.to_s)
    date.beginning_of_month
  end

  def error(row, message)
    prefixed = row.origin.present? ? "#{row.origin}: #{message}" : message
    @errors << prefixed
    prefixed
  end

  # Count each account once even when the file has many monthly rows for it.
  def note_account(account, created:)
    return if @seen_account_ids.include?(account.id)

    @seen_account_ids << account.id
    if created
      @accounts_created += 1
    else
      @accounts_updated += 1
    end
  end

  # Same branches as import_row, but returns an Entry and never saves.
  # Later months of a new account in this file are :keep on the account.
  def preview_row(row)
    name = row.name.to_s.strip.presence
    if name.blank?
      return Entry.new(row: row, error: error(row, "name is required"))
    end

    if kind_for(row).present? && !Account::KINDS.include?(kind_for(row))
      return Entry.new(row: row, error: error(row, "kind must be one of #{Account::KINDS.join(', ')}"))
    end

    existing = find_account(row)
    key = [ name, row.institution.presence ]

    if existing
      changes = proposed_account_changes(existing, row, name)
      probe = Account.new(existing.attributes)
      assign_account_attributes(probe, row, name)
      unless probe.valid?
        return Entry.new(row: row, account_action: changes.any? ? :update : :keep,
                         account_changes: changes, error: error(row, probe.errors.full_messages.to_sentence))
      end
      value = preview_value(existing, row)
      Entry.new(row: row, account_action: changes.any? ? :update : :keep,
                account_changes: changes, **value)
    elsif (pending = @pending_new_accounts[key])
      value = preview_value(pending, row)
      Entry.new(row: row, account_action: :keep, **value)
    else
      if kind_for(row).blank?
        return Entry.new(row: row, error: error(row, "kind is required when creating a new account"))
      end

      probe = Account.new(account_attributes(row, name))
      unless probe.valid?
        return Entry.new(row: row, error: error(row, probe.errors.full_messages.to_sentence))
      end

      @pending_new_accounts[key] = probe
      value = preview_value(probe, row)
      Entry.new(row: row, account_action: :create, **value)
    end
  rescue ArgumentError, TypeError => e
    Entry.new(row: row, error: error(row, e.message))
  end

  # Classify the value half of a row without initializing AR records.
  def preview_value(account, row)
    if row.value_id.blank? && row.recorded_on.blank? && row.amount.blank?
      return { value_action: :none, value_changes: {} }
    end

    if (row.recorded_on.blank? || row.amount.blank?) && row.value_id.blank?
      return { value_action: :none, value_changes: {},
               error: error(row, "recorded_on and amount must both be present to import a value") }
    end

    if account.kind == "credit_card" && (row.recorded_on.present? || row.amount.present?)
      return { value_action: :none, value_changes: {},
               error: error(row, "credit cards do not track balances — leave recorded_on and amount blank") }
    end

    return { value_action: :none, value_changes: {} } if account.kind == "credit_card"

    recorded_on = coerce_recorded_on(row)
    existing = find_existing_value(account, row, recorded_on)

    if existing.nil?
      return { value_action: :create, value_changes: {} }
    end

    changes = {}
    if recorded_on && existing.recorded_on != recorded_on
      changes["recorded_on"] = [ existing.recorded_on, recorded_on ]
    end
    unless row.amount.nil?
      new_amount = cast_attribute(AccountValue, :amount, row.amount)
      unless existing.amount == new_amount
        changes["amount"] = [ existing.amount, new_amount ]
      end
    end

    { value_action: changes.any? ? :update : :keep, value_changes: changes }
  end

  # Like find_value, but never builds a new record (preview must not dirty state).
  def find_existing_value(account, row, recorded_on)
    if row.value_id.present?
      value = AccountValue.find_by(id: row.value_id)
      if value
        if account.new_record? || value.account_id != account.id
          raise ArgumentError, "value_id belongs to a different account"
        end
        return value
      end
    end

    raise ArgumentError, "recorded_on is required when value_id is missing" if recorded_on.blank?

    return if account.new_record?

    AccountValue.find_by(account: account, recorded_on: recorded_on)
  end

  # Attribute diffs after AR casting, without assigning on the persisted account.
  def proposed_account_changes(existing, row, name)
    current = existing.attributes.slice(*ACCOUNT_COMPARE_KEYS)
    proposed = current.merge("name" => name, "institution" => row.institution.presence)
    proposed["kind"] = kind_for(row) if kind_for(row)
    proposed["interest_rate"] = row.interest_rate unless row.interest_rate.nil?
    proposed["term_months"] = row.term_months unless row.term_months.nil?
    proposed["original_principal"] = row.original_principal unless row.original_principal.nil?

    casted = Account.new(proposed).attributes.slice(*ACCOUNT_COMPARE_KEYS)
    changes = {}
    current.each do |key, old_val|
      new_val = casted[key]
      changes[key] = [ old_val, new_val ] unless old_val == new_val
    end
    changes
  end

  # Cast a raw CSV value the way the model would on assign (Float → decimal, etc.).
  def cast_attribute(model, field, raw)
    model.new(field => raw).public_send(field)
  end
end
