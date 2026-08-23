class ImportsController < ApplicationController
  # File codec for upload/download. Swap (or pick by filename) to add JSON
  # without changing PortfolioImport / PortfolioExport.
  CODEC = PortfolioFormats::Csv

  def show
  end

  def create
    file = params[:file]

    if file.blank?
      redirect_to import_path, alert: "Choose a CSV file to import."
      return
    end

    decoded = CODEC.parse(file)
    result = if decoded.errors.any?
      PortfolioImport::Result.new(
        accounts_created: 0, accounts_updated: 0, values_upserted: 0, errors: decoded.errors
      )
    else
      PortfolioImport.new(decoded.rows).call
    end

    if result.success?
      redirect_to root_path, notice: "Import complete — #{result.summary} 🎉"
    else
      redirect_to import_path, alert: "Import failed: #{result.errors.first(5).join(' · ')}"
    end
  end

  def template
    send_data CODEC.template,
              filename: "portfolio-import-template.#{CODEC.extension}",
              type: CODEC.content_type,
              disposition: "attachment"
  end

  def export
    send_data CODEC.generate(PortfolioExport.rows),
              filename: "portfolio-#{Date.current.iso8601}.#{CODEC.extension}",
              type: CODEC.content_type,
              disposition: "attachment"
  end
end
