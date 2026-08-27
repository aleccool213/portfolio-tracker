require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # --no-sandbox so the suite also runs inside a container (CI runners don't
  # need it, but it's harmless there).
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
  end
end
