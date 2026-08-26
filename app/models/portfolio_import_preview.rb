# Dry-run of PortfolioImport: classify each row as create / update / keep
# without writing. Matching rules live in PortfolioImport::Matching.
class PortfolioImportPreview
  include PortfolioImport::Matching

  ACCOUNT_COMPARE_KEYS = %w[name institution kind interest_rate term_months original_principal].freeze

  # One CSV row as it would be applied: :create / :update / :keep / :none.
  # account_changes / value_changes are { "field" => [before, after] } on updates.
  Entry = Data.define(:row, :account_action, :value_action, :account_changes, :value_changes, :error) do
    def initialize(row:, account_action: nil, value_action: :none, account_changes: {}, value_changes: {}, error: nil)
      super
    end
  end

  # success? is false when any row has an error (confirm hidden).
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
    @errors = []
    @pending_new_accounts = {}
  end

  # Classify each row. Does not mutate persisted records.
  def call
    entries = @rows.map { |row| preview_row(row) }
    Plan.new(entries: entries, errors: @errors)
  end

  private

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

  # Like persist find_value, but never builds a new record.
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
