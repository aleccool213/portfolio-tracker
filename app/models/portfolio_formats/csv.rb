require "csv"

module PortfolioFormats
# CSV codec: the only format-specific code for transfer. Spreadsheet
# quirks ($ / commas in amounts, header rows) live here.
class Csv
  REQUIRED_HEADERS = %w[name institution kind recorded_on amount].freeze
  OPTIONAL_HEADERS = %w[interest_rate term_months original_principal].freeze
  HEADERS = (REQUIRED_HEADERS + OPTIONAL_HEADERS).freeze

  Decoded = Data.define(:rows, :errors)

  def self.content_type = "text/csv"
  def self.extension = "csv"

  def self.parse(io)
    errors = []
    table = CSV.parse(io.read, headers: true, header_converters: :downcase, skip_blanks: true)
    headers = table.headers.compact.map { |h| h.to_s.strip.downcase }
    missing = REQUIRED_HEADERS - headers
    if missing.any?
      return Decoded.new(rows: [], errors: [ "Missing required column(s): #{missing.join(', ')}" ])
    end

    rows = []
    table.each_with_index do |raw, index|
      origin = "Line #{index + 2}" # header is line 1
      hash = raw.to_h.transform_values { |v| v.to_s.strip.presence }
      recorded_on, date_error = coerce_date(hash["recorded_on"], origin)
      amount, amount_error = coerce_amount(hash["amount"], origin)
      if date_error || amount_error
        errors.concat([ date_error, amount_error ].compact)
        next
      end

      rows << PortfolioRow.new(
        name: hash["name"],
        institution: hash["institution"],
        kind: hash["kind"],
        recorded_on: recorded_on,
        amount: amount,
        interest_rate: hash["interest_rate"],
        term_months: hash["term_months"],
        original_principal: hash["original_principal"],
        origin: origin
      )
    end

    Decoded.new(rows: rows, errors: errors)
  rescue CSV::MalformedCSVError => e
    Decoded.new(rows: [], errors: [ "Could not parse CSV: #{e.message}" ])
  end

  def self.generate(rows)
    CSV.generate(headers: true) do |csv|
      csv << HEADERS
      Array(rows).each do |row|
        csv << [
          row.name,
          row.institution,
          row.kind,
          row.recorded_on&.iso8601 || row.recorded_on,
          decimal(row.amount),
          decimal(row.interest_rate),
          row.term_months,
          decimal(row.original_principal)
        ]
      end
    end
  end

  def self.example_path
    Rails.root.join("lib/portfolio_formats/example.csv")
  end

  def self.template
    example_path.read
  end

  def self.coerce_date(raw, origin)
    return [ nil, nil ] if raw.blank?

    [ Date.parse(raw), nil ]
  rescue ArgumentError, TypeError
    [ nil, "#{origin}: recorded_on is not a valid date (got #{raw.inspect})" ]
  end
  private_class_method :coerce_date

  def self.coerce_amount(raw, origin)
    return [ nil, nil ] if raw.blank?

    cleaned = raw.to_s.gsub(/[$,\s]/, "")
    cleaned = cleaned.sub(/\A\((.*)\)\z/, '-\1')
    [ Float(cleaned), nil ]
  rescue ArgumentError, TypeError
    [ nil, "#{origin}: amount is not a number (got #{raw.inspect})" ]
  end
  private_class_method :coerce_amount

  def self.decimal(value)
    return if value.nil?

    value.is_a?(BigDecimal) ? value.to_s("F") : value.to_s
  end
  private_class_method :decimal
end
end
