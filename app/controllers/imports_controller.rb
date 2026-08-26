class ImportsController < ApplicationController
  # File codec for upload/download. Swap (or pick by filename) to add JSON
  # without changing PortfolioImport / PortfolioExport.
  CODEC = PortfolioFormats::Csv

  def show
  end

  # Parse the upload and render a create/update preview. Does not persist.
  def create
    file = params[:file]

    if file.blank?
      redirect_to import_path, alert: "Choose a CSV file to import."
      return
    end

    csv_body = file.read
    decoded = CODEC.parse(StringIO.new(csv_body))
    if decoded.errors.any?
      redirect_to import_path, alert: "Import failed: #{decoded.errors.first(5).join(' · ')}"
      return
    end

    @plan = PortfolioImportPreview.new(decoded.rows).call
    @csv_body = csv_body
    render :preview
  end

  # Apply the CSV from the preview form (hidden field), then redirect.
  def confirm
    csv_body = params[:csv]
    if csv_body.blank?
      redirect_to import_path, alert: "Upload a CSV again to import."
      return
    end

    decoded = CODEC.parse(StringIO.new(csv_body))
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

  # Committed example CSV used as the downloadable template.
  def template
    send_data CODEC.template,
              filename: "portfolio-example.#{CODEC.extension}",
              type: CODEC.content_type,
              disposition: "attachment"
  end

  # Current accounts + values in the same columns import expects.
  def export
    send_data CODEC.generate(PortfolioExport.rows),
              filename: "portfolio-#{Date.current.iso8601}.#{CODEC.extension}",
              type: CODEC.content_type,
              disposition: "attachment"
  end
end
