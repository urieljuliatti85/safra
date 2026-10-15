require "test_helper"

# A grade usa aria-label nas células (sem <label> visível por célula).
Capybara.enable_aria_label = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]
end
