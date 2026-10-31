RSpec.describe 'Guestit MCP stays' do
  let(:server_context) { { configuration: } }

  let(:stay) do
    {
      status: 'found',
      listing_slug: 'lake-house',
      name: 'Lake house',
      summary: '<img src=x onerror="window.injected=true"> Quiet by the lake.',
      website_url: 'https://localhost/listings/lake-house',
      images: [],
      occupancy: { num_guests: 4, num_bedrooms: 2, num_beds: 3, pets_allowed: true },
      rating_score: 4.8,
      num_reviews: 12,
      amenities: %w[Wi-Fi Kitchen],
      cancellation_policy: 'Free cancellation until seven days before arrival.',
      house_rules: 'No smoking.',
      price: {
        status: 'estimated',
        currency: 'SEK',
        total_minor: 125_000,
        unit: 'night',
        unit_price_minor: 25_000,
        cleaning_fee_minor: 15_000,
        guest_fees: [],
        payment_schedule: [{ payment_date: '2026-11-10', amount_minor: 125_000 }],
        start_date: '2026-12-10',
        end_date: '2026-12-15',
        inventory_held: false
      }
    }
  end
  let(:other_stay) { stay.merge(listing_slug: 'city-flat', name: 'City flat', website_url: 'https://localhost/listings/city-flat') }
  let(:stays) { [stay, other_stay] }
  let(:view) { 'search' }
  let(:locale) { 'en' }
  let(:tool_result) { { structuredContent: payload } }
  let(:host_protocol_version) { '2026-01-26' }
  let(:defer_tool_responses) { false }
  let(:notify_tool_responses) { false }
  let(:host_capabilities) { { serverTools: {}, openLinks: {} } }
  let(:host_context) { { theme: 'light' } }
  let(:answer_display_mode) { true }
  let(:comparison_arguments) { payload[:requested_stay].transform_keys(&:to_s).merge('locale' => 'en', 'listing_slugs' => %w[lake-house city-flat]) }
  let(:payload) do
    {
      view:,
      locale:,
      calculated_at: '2026-10-30T10:00:00Z',
      requested_stay: { start_date: '2026-12-10', end_date: '2026-12-15', num_guests: 2 },
      stays:,
      pagination: { page: 1, total_pages: 1, total_count: stays.size }
    }
  end
  let(:host_page) do
    values = {
      widget_html: script_json(CoreMcp::Widget.contents(server_context:).text),
      initial_result: script_json(tool_result),
      protocol_version: script_json(host_protocol_version),
      capabilities: script_json(host_capabilities),
      context: script_json(host_context),
      defer_tool_responses:,
      notify_tool_responses:,
      answer_display_mode:
    }
    template = File.read(File.expand_path('../fixtures/mcp/host.html.erb', __dir__))

    ERB.new(template).result_with_hash(values)
  end

  def script_json(value)
    JSON.generate(value).gsub('<', '\\u003c')
  end

  def compare_stays(*names)
    click_button 'Compare'
    names.each { |name| click_button "Select #{name} for comparison" }
    click_button "Compare #{names.size}"
  end

  def post_host_notification(method, params)
    execute_script(<<~JS, method, params)
      document.getElementById('stays').contentWindow.postMessage({ jsonrpc: '2.0', method: arguments[0], params: arguments[1] }, '*')
    JS
  end

  def release_tool_responses
    execute_script('window.releaseToolResponses()')
    evaluate_script(<<~JS)
      new Promise(resolve => {
        const frame = document.getElementById('stays')
        window.addEventListener('message', function listener(event) {
          if (event.source !== frame.contentWindow || event.data.id !== 'test-barrier') return
          window.removeEventListener('message', listener)
          resolve(true)
        })
        frame.contentWindow.postMessage({ jsonrpc: '2.0', id: 'test-barrier', method: 'ping' }, '*')
      })
    JS
  end

  before do
    page.driver.with_playwright_page { |browser_page| browser_page.set_content(host_page) }
  end

  it 'shows each stay as a card with its dated total' do
    within_frame('stays') do
      expect(page).to have_css('[role="img"][aria-label="Guestit"]')
      expect(page).to have_text(/10[[:space:]]*–[[:space:]]*15 Dec 2026 · 5 nights · 2 guests/)
      expect(page).to have_css('article', text: 'Lake house', count: 1).and have_text('SEK 1,250 total').and have_text('5 nights · SEK 250 per night')
      expect(page).to have_text('Prices include cleaning and fees and are not held until you book.')
      expect(page).to have_no_link('Book on Guestit')
    end
  end

  it 'opens the details with the price breakdown and escaped listing text' do
    within_frame('stays') do
      click_button 'View Lake house'
      expect(page).to have_css('h2:focus', text: 'Lake house').and have_text('Includes: Cleaning SEK 150')
      expect(page).to have_text('<img src=x onerror="window.injected=true"> Quiet by the lake.').and have_no_css('img')
    end
  end

  it 'hands the stay to Guestit through the host and tells the model' do
    within_frame('stays') do
      click_button 'View Lake house'
      click_link 'Book on Guestit'
    end

    expect(page).to have_css('body[data-opened="1"][data-model-context="2"]', visible: :all)
    expect(page.evaluate_script('window.opened')).to eq(['https://localhost/listings/lake-house'])
    expect(page.evaluate_script('window.modelContext.at(-1)')).to include('opened "Lake house" (listing_slug lake-house)')
      .and include('opened the booking page for "Lake house"')
  end

  it 'loads details and returns to the original results' do
    within_frame('stays') do
      click_button 'View Lake house'
      find('summary', text: 'Cancellation policy').click
      expect(page).to have_text('Free cancellation until seven days before arrival.')
      click_button 'Back to results'
      expect(page).to have_css('button[data-listing-slug="lake-house"]:focus').and have_button('View City flat')
    end
  end

  it 'compares the selected stays for the requested dates and guests' do
    within_frame('stays') do
      compare_stays('Lake house', 'City flat')
      expect(page).to have_css('h2', text: 'Compare stays').and have_link('Book on Guestit: City flat').and have_no_text('Lowest total')
    end

    expect(page).to have_css('body[data-model-context="1"]', visible: :all)
    expect(page.evaluate_script('window.calls')).to eq([{ 'name' => 'compare_stays', 'arguments' => comparison_arguments }])
    expect(page.evaluate_script('window.modelContext')).to contain_exactly(a_string_including('compared "Lake house"'))
  end

  context 'when the compared totals differ' do
    let(:other_stay) { super().merge(price: stay[:price].merge(total_minor: 99_000)) }

    it 'marks the lowest total' do
      within_frame('stays') do
        compare_stays('Lake house', 'City flat')
        expect(page).to have_css('td', text: /SEK 990.*Lowest total/m, count: 1)
      end
    end
  end

  context 'with a dated booking link' do
    let(:other_stay) do
      super().merge(website_url: 'https://localhost/en/listings/city-flat?adults=2&endDate=2026-12-15&startDate=2026-12-10')
    end

    it 'opens the chosen comparison with its dates and guests' do
      within_frame('stays') do
        compare_stays('Lake house', 'City flat')
        click_link 'Book on Guestit: City flat'
      end

      expect(page).to have_css('body[data-opened="1"][data-model-context="2"]', visible: :all)
      expect(page.evaluate_script('window.opened')).to eq(['https://localhost/en/listings/city-flat?adults=2&endDate=2026-12-15&startDate=2026-12-10'])
    end
  end

  it 'replaces the search results when the host refines the search' do
    within_frame('stays') { expect(page).to have_button('View Lake house').and have_button('View City flat') }
    refined = payload.merge(stays: [stay], pagination: { page: 1, total_pages: 1, total_count: 1 })
    post_host_notification('ui/notifications/tool-result', structuredContent: refined)

    within_frame('stays') { expect(page).to have_button('View Lake house').and have_no_button('View City flat') }
  end

  it 'preserves selected stays when the host reorders the stay fields' do
    within_frame('stays') do
      click_button 'Compare'
      click_button 'Select Lake house for comparison'
      click_button 'Select City flat for comparison'
    end
    reordered = { num_guests: 2, end_date: '2026-12-15', start_date: '2026-12-10' }
    post_host_notification('ui/notifications/tool-result', structuredContent: payload.merge(requested_stay: reordered))

    within_frame('stays') { expect(page).to have_button('Compare 2', disabled: false) }
  end

  it 'ignores tool results from a source other than the host' do
    within_frame('stays') do
      expect(page).to have_text('Lake house')
      execute_script(<<~JS)
        window.addEventListener('message', ({ data }) => { if (data === 'foreign-finished') document.body.dataset.foreignFinished = 'true' })
        window.postMessage({ jsonrpc: '2.0', method: 'ui/notifications/tool-result', params: { structuredContent: { view: 'search', locale: 'en', stays: [] } } }, '*')
        window.postMessage('foreign-finished', '*')
      JS
      find('body[data-foreign-finished]', visible: :all)
      expect(page).to have_text('Lake house').and have_no_text('No stays match this search.')
    end
  end

  it 'keeps opened sections through a theme change' do
    within_frame('stays') do
      click_button 'View Lake house'
      find('summary', text: 'House rules').click
    end
    post_host_notification('ui/notifications/host-context-changed', theme: 'dark')

    within_frame('stays') { expect(page).to have_text('No smoking.').and have_link('Book on Guestit') }
  end

  context 'when the host offers fullscreen' do
    let(:host_context) { { theme: 'light', displayMode: 'inline', availableDisplayModes: %w[inline fullscreen] } }

    it 'opens details in fullscreen and returns to the cards when the host closes it' do
      within_frame('stays') do
        click_button 'View Lake house'
        expect(page).to have_css('body[data-display-mode="fullscreen"]', visible: :all).and have_link('Book on Guestit')
      end
      post_host_notification('ui/notifications/host-context-changed', displayMode: 'inline')

      within_frame('stays') { expect(page).to have_button('View Lake house').and have_no_link('Book on Guestit') }
      expect(page.evaluate_script('window.displayModes')).to eq(['fullscreen'])
    end

    context 'when the host also notifies the detail result' do
      let(:notify_tool_responses) { true }

      it 'returns to the cards when the host closes fullscreen' do
        within_frame('stays') do
          click_button 'View Lake house'
          expect(page).to have_link('Book on Guestit')
        end
        post_host_notification('ui/notifications/host-context-changed', displayMode: 'inline')

        within_frame('stays') { expect(page).to have_button('View Lake house').and have_no_link('Book on Guestit') }
      end
    end

    context 'when the host never answers the display mode request' do
      let(:answer_display_mode) { false }

      it 'holds the cards, then opens the details inline' do
        within_frame('stays') do
          click_button 'View Lake house'
          expect(page).to have_button('View City flat', disabled: true)
          expect(page).to have_link('Book on Guestit')
        end

        expect(page.evaluate_script('window.calls').map { |call| call.fetch('name') }).to eq(['stay_details'])
      end
    end
  end

  context 'when the host notifies before replying to a detail request' do
    let(:notify_tool_responses) { true }

    it 'moves focus to the new details' do
      within_frame('stays') do
        click_button 'View Lake house'
        expect(page).to have_css('h2:focus', text: 'Lake house')
      end
    end

    context 'when the notified read fails' do
      before do
        execute_script('window.failTools = true')
        within_frame('stays') { click_button 'View Lake house' }
      end

      it 'retains the failed read for retry' do
        within_frame('stays') { expect(page).to have_text('Details are temporarily unavailable.').and have_button('Try again') }
        execute_script('window.failTools = false')

        within_frame('stays') do
          click_button 'Try again'
          expect(page).to have_link('Book on Guestit')
        end
      end
    end
  end

  context 'when details are loading' do
    let(:defer_tool_responses) { true }

    before { within_frame('stays') { click_button 'View Lake house' } }

    it 'replaces the cards until the request finishes' do
      within_frame('stays') do
        expect(page).to have_text('Loading the stay…').and have_css('main[aria-busy="true"]')
        expect(page).to have_no_button('View Lake house').and have_button('Back to results', disabled: true)
      end
    end

    it 'keeps newer chat results when the earlier detail response arrives' do
      latest = payload.merge(stays: [stay.merge(name: 'Latest stay')])
      post_host_notification('ui/notifications/tool-result', structuredContent: latest)
      within_frame('stays') { expect(page).to have_button('View Latest stay') }
      release_tool_responses

      within_frame('stays') { expect(page).to have_button('View Latest stay').and have_no_link('Book on Guestit') }
    end

    it 'does not revive an earlier failed read after newer chat results' do
      execute_script("window.toolReplies[0].result = { isError: true, content: [{ type: 'text', text: 'Old failure' }] }")
      latest = payload.merge(stays: [stay.merge(name: 'Latest stay')])
      post_host_notification('ui/notifications/tool-result', structuredContent: latest)
      within_frame('stays') { expect(page).to have_button('View Latest stay') }
      release_tool_responses

      within_frame('stays') { expect(page).to have_button('View Latest stay').and have_no_text('Old failure').and have_no_button('Try again') }
    end

    it 'keeps a cancelled request from restoring prior cards' do
      post_host_notification('ui/notifications/tool-cancelled', {})
      within_frame('stays') { expect(page).to have_text('This request was cancelled.') }
      release_tool_responses

      within_frame('stays') { expect(page).to have_no_button('View Lake house').and have_no_link('Book on Guestit') }
    end
  end

  context 'when a detail request fails' do
    before do
      execute_script('window.failTools = true')
      within_frame('stays') { click_button 'View Lake house' }
    end

    it 'clears prior cards and offers recovery' do
      within_frame('stays') do
        expect(page).to have_text('Details are temporarily unavailable.')
        expect(page).to have_button('Try again').and have_button('Back to results')
        expect(page).to have_no_button('View Lake house')
      end
    end

    it 'retries the failed read' do
      execute_script('window.failTools = false')
      within_frame('stays') do
        click_button 'Try again'
        expect(page).to have_link('Book on Guestit')
      end
    end
  end

  context 'without host tool access' do
    let(:host_capabilities) { { openLinks: {} } }

    it 'links each card to Guestit without unusable detail controls' do
      within_frame('stays') do
        expect(page).to have_no_button('View Lake house').and have_no_button('Compare')
        click_link 'Lake house'
      end

      expect(page).to have_css('body[data-opened="1"]', visible: :all)
      expect(page.evaluate_script('window.opened')).to eq(['https://localhost/listings/lake-house'])
    end
  end

  context 'with a narrow screen and long Swedish content' do
    let(:locale) { 'sv' }
    let(:name) { 'Strandhusetvidsjön' * 8 }
    let(:stays) { [stay.merge(name:)] }

    before { page.current_window.resize_to(375, 812) }

    it 'keeps the booking action reachable from the keyboard' do
      within_frame('stays') do
        expect(page.evaluate_script('document.documentElement.scrollWidth <= document.documentElement.clientWidth')).to be(true)
        find_button("Visa #{name}").send_keys(:enter)
        find_link('Boka på Guestit').send_keys(:enter)
      end

      expect(page).to have_css('body[data-opened="1"]', visible: :all)
      expect(page.evaluate_script('window.opened')).to eq(['https://localhost/listings/lake-house'])
    end

    it 'keeps the active widget usable through responsive resizes' do
      [375, 768, 1280].each do |width|
        page.current_window.resize_to(width, 812)
        within_frame('stays') do
          evaluate_script('new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))')
          expect(page).to have_button("Visa #{name}")
          expect(page.evaluate_script('document.documentElement.scrollWidth <= document.documentElement.clientWidth')).to be(true)
        end
      end
    end
  end

  context 'when a listing contains an untrusted link and image' do
    let(:stays) do
      [stay.merge(website_url: 'https://guestit.se.attacker.test/listings/lake-house', images: [{ url: 'javascript:alert(1)', alt_text: 'Unsafe' }])]
    end

    it 'omits the external navigation and image' do
      within_frame('stays') do
        click_button 'View Lake house'
        expect(page).to have_css('h2', text: 'Lake house')
        expect(page).to have_no_link('Book on Guestit').and have_no_css('img')
      end
    end
  end

  context 'with no stays' do
    let(:stays) { [] }

    it 'shows the empty state' do
      within_frame('stays') do
        expect(page).to have_text('No stays match this search.')
        expect(page).to have_no_button('Compare')
      end
    end
  end

  context 'without dates' do
    let(:payload) { super().merge(requested_stay: { start_date: nil, end_date: nil, num_guests: 2 }) }
    let(:stays) do
      [stay.merge(price: stay[:price].merge(status: 'dates_required', total_minor: nil)), other_stay.merge(price: stay[:price].merge(status: 'dates_required', total_minor: nil))]
    end

    it 'asks for dates instead of offering a comparison' do
      within_frame('stays') do
        expect(page).to have_text('Add dates for a price', count: 2).and have_text('Add dates in the chat to compare prices.')
        expect(page).to have_no_button('Compare')
      end
    end
  end

  context 'when the tool fails' do
    let(:tool_result) { { isError: true, content: [{ type: 'text', text: 'Please choose valid dates.' }] } }

    it 'shows the failure without interpreting it as markup' do
      within_frame('stays') { expect(page).to have_text('Please choose valid dates.') }
    end
  end

  context 'when check-out is before check-in' do
    let(:tool_result) do
      context = server_context.merge(today: Date.new(2026, 10, 30))
      arguments = {
        listing_slug: 'lake-house',
        num_guests: 2,
        start_date: '2026-12-15',
        end_date: '2026-12-10'
      }

      CoreMcp::Tools::StayDetails.call(server_context: context, **arguments).to_h
    end

    it 'shows the date refusal without offering a stay' do
      within_frame('stays') do
        expect(page).to have_text('Check-out must be after check-in.')
        expect(page).to have_no_button('View Lake house').and have_no_link('Book on Guestit')
      end
    end
  end

  context 'when the tool refuses the arguments' do
    let(:tool_result) { { isError: true, content: [{ type: 'text', text: 'Invalid arguments: object property at `/location_id` is a disallowed additional property' }] } }

    it 'shows a traveler message instead of the schema error' do
      within_frame('stays') do
        expect(page).to have_text("Something in this request couldn't be used.").and have_no_text('additional property')
      end
    end
  end

  context 'when the host negotiates an unsupported UI protocol' do
    let(:host_protocol_version) { '2024-11-05' }

    it 'does not initialize the widget' do
      within_frame('stays') { expect(page).to have_text('Open Guestit from your chat to explore stays.') }
      expect(page.evaluate_script('window.hostMessages')).not_to include('ui/notifications/initialized')
    end
  end

  context 'with Swedish output' do
    let(:locale) { 'sv' }

    it 'uses the result language' do
      within_frame('stays') do
        expect(page).to have_text(/10[[:space:]]*–[[:space:]]*15 dec. 2026 · 5 nätter · 2 gäster/).and have_text(/1[[:space:]]250[[:space:]]kr totalt/)
        expect(page).to have_button('Visa Lake house').and have_button('Jämför')
      end
    end
  end
end
