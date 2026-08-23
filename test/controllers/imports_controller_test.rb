require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  test "show import form" do
    get import_url
    assert_response :success
    assert_select "form[action=?]", import_path
    assert_select "input[type=file][name=file]"
    assert_select "a[href=?]", template_import_path
  end

  test "template downloads the committed example csv" do
    get template_import_url
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/portfolio-example\.csv/, response.headers["Content-Disposition"])
    assert_equal PortfolioFormats::Csv.template, response.body
    assert_match(/Example TFSA/, response.body)
  end

  test "create imports csv and redirects to dashboard" do
    csv = <<~CSV
      name,institution,kind,recorded_on,amount
      Controller Import TFSA,Wealthsimple,tfsa,2026-03-01,50000
    CSV

    file = Tempfile.new([ "portfolio", ".csv" ])
    file.write(csv)
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "text/csv")

    assert_difference -> { Account.count } => 1, -> { AccountValue.count } => 1 do
      post import_url, params: { file: uploaded }
    end

    assert_redirected_to root_path
    assert_match(/Import complete/, flash[:notice])
  ensure
    file.close!
  end

  test "create without file shows alert" do
    post import_url, params: {}
    assert_redirected_to import_path
    assert_match(/Choose a CSV file/, flash[:alert])
  end

  test "create with bad csv shows alert and does not persist" do
    csv = <<~CSV
      name,institution,kind,recorded_on,amount
      Bad Kind Account,Bank,not_a_kind,2026-01-01,10
    CSV

    file = Tempfile.new([ "bad", ".csv" ])
    file.write(csv)
    file.rewind
    uploaded = Rack::Test::UploadedFile.new(file.path, "text/csv")

    assert_no_difference [ "Account.count", "AccountValue.count" ] do
      post import_url, params: { file: uploaded }
    end

    assert_redirected_to import_path
    assert_match(/Import failed/, flash[:alert])
  ensure
    file.close!
  end

  test "dashboard links to import and export" do
    get root_url
    assert_response :success
    assert_select "a[href=?]", import_path
    assert_select "a[href=?]", export_import_path
  end

  test "export downloads current portfolio csv" do
    get export_import_url
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/portfolio-#{Date.current.iso8601}\.csv/, response.headers["Content-Disposition"])
    assert_match(/Managed TFSA/, response.body)
    assert_match(/Home mortgage/, response.body)
  end

  test "show includes export link" do
    get import_url
    assert_response :success
    assert_select "a[href=?]", export_import_path, text: "Export CSV"
  end
end
