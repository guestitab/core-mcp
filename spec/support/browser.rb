Capybara.register_driver(:playwright) do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: :webkit,
    playwright_cli_executable_path: File.expand_path('../../bin/playwright', __dir__),
    locale: 'en-US',
    headless: true,
    viewport: { width: 1440, height: 900 }
  )
end

Capybara.configure do |config|
  config.default_driver = :playwright
  config.default_max_wait_time = 5
  config.enable_aria_label = true
  config.enable_aria_role = true
end

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/features/}) { |metadata| metadata[:type] = :feature }

  config.before(:each, type: :feature) do
    @browser_errors = []
    page.driver.with_playwright_page do |browser_page|
      browser_page.on('pageerror', ->(error) { @browser_errors << error.message })
    end
  end

  config.after(:each, type: :feature) do
    Capybara.reset_sessions!
    expect(@browser_errors).to be_empty
  end
end
