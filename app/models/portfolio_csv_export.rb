# Dumps accounts (+ monthly values) in the same CSV shape PortfolioCsvImport
# reads, so an export can be re-imported on a fresh deploy.
require "csv"

class PortfolioCsvExport
  def self.call(accounts = Account.includes(:account_values).order(:kind, :name))
    CSV.generate(headers: true) do |csv|
      csv << PortfolioCsvImport::HEADERS
      Array(accounts).each do |account|
        values = account.account_values.chronological.to_a
        if values.empty?
          csv << row_for(account, value: nil)
        else
          values.each { |value| csv << row_for(account, value: value) }
        end
      end
    end
  end

  def self.row_for(account, value:)
    [
      account.name,
      account.institution,
      account.kind,
      value&.recorded_on&.iso8601,
      decimal(value&.amount),
      decimal(account.interest_rate),
      account.term_months,
      decimal(account.original_principal)
    ]
  end
  private_class_method :row_for

  def self.decimal(value)
    return if value.nil?

    value.to_s("F")
  end
  private_class_method :decimal
end
