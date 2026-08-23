# Parses a CSV of accounts (+ optional monthly values) and upserts them.
#
# Expected headers (case-insensitive, order free):
#   name, institution, kind, recorded_on, amount
# Optional (needed when creating a liability): interest_rate, term_months,
# original_principal.
#
# - name + kind create/find an Account (matched on name + institution).
# - recorded_on + amount upsert an AccountValue for that account.
# - Credit cards can be imported as accounts but never receive values.
# - recorded_on is normalized to the 1st of its month (matches value entry).
require "csv"

class PortfolioCsvImport
  REQUIRED_HEADERS = %w[name institution kind recorded_on amount].freeze
  OPTIONAL_HEADERS = %w[interest_rate term_months original_principal].freeze
  HEADERS = (REQUIRED_HEADERS + OPTIONAL_HEADERS).freeze

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

  def self.template_csv
    CSV.generate(headers: true) do |csv|
      csv << HEADERS
      csv << [ "Managed TFSA", "Wealthsimple", "tfsa", "2026-01-01", "42000.00", "", "", "" ]
      csv << [ "Managed TFSA", "Wealthsimple", "tfsa", "2026-02-01", "43200.50", "", "", "" ]
      csv << [ "Home mortgage", "RBC", "liability", "2026-01-01", "-318000.00", "4.89", "60", "450000" ]
      csv << [ "Aeroplan Visa", "TD", "credit_card", "", "", "", "", "" ]
    end
  end

  def initialize(io)
    @io = io
    @accounts_created = 0
    @accounts_updated = 0
    @values_upserted = 0
    @errors = []
    @seen_account_ids = Set.new
  end

  def call
    rows = parse_rows
    return failure if @errors.any?

    Account.transaction do
      rows.each_with_index do |row, index|
        import_row(row, line_number: index + 2) # header is line 1
      end
      raise ActiveRecord::Rollback if @errors.any?
    end

    # Only report account counts when the whole import committed.
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

  def failure
    Result.new(accounts_created: 0, accounts_updated: 0, values_upserted: 0, errors: @errors)
  end

  def parse_rows
    table = CSV.parse(@io.read, headers: true, header_converters: :downcase, skip_blanks: true)
    missing = REQUIRED_HEADERS - table.headers.compact.map { |h| h.to_s.strip.downcase }
    if missing.any?
      @errors << "Missing required column(s): #{missing.join(', ')}"
      return []
    end

    table.map { |row| row.to_h.transform_values { |v| v.to_s.strip.presence } }
  rescue CSV::MalformedCSVError => e
    @errors << "Could not parse CSV: #{e.message}"
    []
  end

  def import_row(row, line_number:)
    name = row["name"]
    if name.blank?
      @errors << "Line #{line_number}: name is required"
      return
    end

    institution = row["institution"]
    kind = row["kind"]&.downcase
    recorded_on_raw = row["recorded_on"]
    amount_raw = row["amount"]

    account = Account.find_by(name: name, institution: institution)

    if account.nil?
      if kind.blank?
        @errors << "Line #{line_number}: kind is required when creating a new account"
        return
      end
      unless Account::KINDS.include?(kind)
        @errors << "Line #{line_number}: kind must be one of #{Account::KINDS.join(', ')}"
        return
      end

      account = Account.create!(
        name: name,
        institution: institution,
        kind: kind,
        interest_rate: row["interest_rate"],
        term_months: row["term_months"],
        original_principal: row["original_principal"]
      )
      note_account(account, created: true)
    else
      note_account(account, created: false)
    end

    return if recorded_on_raw.blank? && amount_raw.blank?

    if recorded_on_raw.blank? || amount_raw.blank?
      @errors << "Line #{line_number}: recorded_on and amount must both be present to import a value"
      return
    end

    if account.kind == "credit_card"
      @errors << "Line #{line_number}: credit cards do not track balances — leave recorded_on and amount blank"
      return
    end

    recorded_on = parse_date(recorded_on_raw, line_number)
    return unless recorded_on

    amount = parse_amount(amount_raw, line_number)
    return unless amount

    value = AccountValue.find_or_initialize_by(account: account, recorded_on: recorded_on.beginning_of_month)
    value.amount = amount
    value.save!
    @values_upserted += 1
  rescue ActiveRecord::RecordInvalid => e
    @errors << "Line #{line_number}: #{e.record.errors.full_messages.to_sentence}"
  end

  def parse_date(raw, line_number)
    Date.parse(raw)
  rescue ArgumentError, TypeError
    @errors << "Line #{line_number}: recorded_on is not a valid date (got #{raw.inspect})"
    nil
  end

  def parse_amount(raw, line_number)
    # Allow "$1,234.56" / "(1234.56)" style from spreadsheets.
    cleaned = raw.gsub(/[$,\s]/, "")
    cleaned = cleaned.sub(/\A\((.*)\)\z/, '-\1')
    Float(cleaned)
  rescue ArgumentError, TypeError
    @errors << "Line #{line_number}: amount is not a number (got #{raw.inspect})"
    nil
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
