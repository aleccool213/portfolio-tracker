class ImportsController < ApplicationController
  def show
  end

  def create
    file = params[:file]

    if file.blank?
      redirect_to import_path, alert: "Choose a CSV file to import."
      return
    end

    result = PortfolioCsvImport.new(file).call

    if result.success?
      redirect_to root_path, notice: "Import complete — #{result.summary} 🎉"
    else
      redirect_to import_path, alert: "Import failed: #{result.errors.first(5).join(' · ')}"
    end
  end

  def template
    send_data PortfolioCsvImport.template_csv,
              filename: "portfolio-import-template.csv",
              type: "text/csv",
              disposition: "attachment"
  end

  def export
    send_data PortfolioCsvExport.call,
              filename: "portfolio-#{Date.current.iso8601}.csv",
              type: "text/csv",
              disposition: "attachment"
  end
end
