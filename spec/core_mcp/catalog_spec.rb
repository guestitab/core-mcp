RSpec.describe CoreMcp::Catalog do
  subject(:catalog) { described_class.new(server_context:) }

  let(:inputs) { CoreMcp::Inputs.new(arguments, today: server_context[:today]) }

  describe '#resolve_destination' do
    let(:arguments) { { query: ' stockholm ', locale: 'sv' } }
    let(:location) { { 'id' => '7', 'slug' => 'stockholm', 'name' => 'Stockholm, Sverige', 'type' => 'LOCALITY', 'countryCode' => 'SE' } }

    before { allow(schema).to receive(:execute).and_return({ 'data' => { 'storedLocation' => location } }) }

    it 'maps a localized stored destination through the fixed query' do
      expect(catalog.resolve_destination(inputs)).to include(
        requested_stay: nil,
        destinations: [{ location_id: '7', slug: 'stockholm', name: 'Stockholm, Sverige', type: 'LOCALITY', country_code: 'SE' }]
      )
      expect(schema).to have_received(:execute).with(
        CoreMcp::Documents::DESTINATION,
        variables: { query: 'stockholm', locale: 'sv' },
        context: { current_guest_token: nil, current_guest_profile_id: nil, ip_address: '192.0.2.1', user_agent: 'MCP test' }
      )
    end
  end

  describe '#search_stays' do
    let(:arguments) { { location_id: 'missing', num_guests: 2, locale: 'sv' } }

    before { allow(schema).to receive(:execute).and_return({ 'data' => { 'storedLocation' => nil } }) }

    it 'refuses an unknown destination before searching stays' do
      expect { catalog.search_stays(inputs) }.to raise_error(CoreMcp::ArgumentError, 'Choose a destination returned by resolve_destination.')
      expect(schema).to have_received(:execute).once.with(CoreMcp::Documents::DESTINATION, variables: { id: 'missing', locale: 'sv' }, context: anything)
    end
  end

  describe '#stay_details' do
    let(:arguments) { { listing_slug: 'missing', num_guests: 2, locale: 'sv' } }
    let(:errors) { [{ 'extensions' => { 'code' => 'record_not_found' } }] }

    before { allow(schema).to receive(:multiplex).and_return([{ 'errors' => errors }]) }

    it 'keeps a missing stay without inventing a price' do
      expect(catalog.stay_details(inputs).fetch(:stays)).to contain_exactly(
        include(listing_slug: 'missing', status: 'not_found', website_url: nil, price: include(status: 'unavailable', total_minor: nil))
      )
    end

    {
      'provider_rate_limited' => 'Guestit har mycket att göra just nu. Försök igen om en minut.',
      'invalid_input' => 'Guestit could not use these search details.',
      'internal_error' => 'Guestit kunde inte slutföra förfrågan. Försök igen senare.'
    }.each do |code, message|
      context "with a #{code} refusal" do
        let(:errors) { [{ 'message' => 'Private provider detail', 'extensions' => { 'code' => code } }] }

        it 'returns the packaged safe refusal in its supported language' do
          expect { catalog.stay_details(inputs) }.to raise_error(described_class::QueryError, message)
        end
      end
    end
  end

  describe 'configuration isolation' do
    let(:arguments) { { listing_slug: 'missing', num_guests: 2 } }
    let(:other_schema) { double('Other schema') }
    let(:other_configuration) { CoreMcp::Config.new(schema: other_schema, cache:, web_origin: 'https://example.net', image_origins: []) }

    before do
      allow(schema).to receive(:multiplex).and_return([{ 'data' => { 'showListing' => nil } }])
      allow(other_schema).to receive(:multiplex)
      catalog
      described_class.new(server_context: server_context.merge(configuration: other_configuration))
    end

    it 'keeps the catalog bound to its own schema' do
      catalog.stay_details(inputs)

      expect(schema).to have_received(:multiplex)
      expect(other_schema).not_to have_received(:multiplex)
    end
  end

  describe 'booking attribution' do
    let(:arguments) { { listing_slug: 'public-stay', num_guests: 3, start_date: '2027-02-12', end_date: '2027-02-15', locale: } }
    let(:locale) { 'en' }
    let(:platform) { nil }
    let(:server_context) do
      super().merge(ai_platform: platform, user_agent: 'ChatGPT-User', _meta: { 'openai/subject': 'private-user-id' })
    end
    let(:listing) do
      {
        'slug' => 'public-stay', 'name' => 'Public stay', 'numReviews' => 0,
        'occupancy' => { 'numGuests' => 4, 'numBedrooms' => 2, 'numBeds' => 3 },
        'previewImages' => [], 'featuredAmenities' => [], 'regularAmenities' => []
      }
    end
    let(:website) { URI.parse(catalog.stay_details(inputs).fetch(:stays).first.fetch(:website_url)) }
    let(:params) { URI.decode_www_form(website.query).to_h }

    before { allow(schema).to receive(:multiplex).and_return([{ 'data' => { 'showListing' => listing } }]) }

    it 'preserves the booking details without trusting client platform claims or exposing identity' do
      expect(website.path).to eq('/en/listings/public-stay')
      expect(params).to eq(
        'adults' => '3', 'endDate' => '2027-02-15', 'startDate' => '2027-02-12', 'utm_source' => 'mcp', 'utm_medium' => 'mcp'
      )
    end

    context 'with an OpenAI platform verified by the host' do
      let(:platform) { 'openai' }

      it 'identifies the OpenAI handoff without a user identifier' do
        expect(params).to eq(
          'adults' => '3', 'endDate' => '2027-02-15', 'startDate' => '2027-02-12', 'utm_source' => 'openai', 'utm_medium' => 'mcp'
        )
      end
    end

    context 'with another platform verified by the host' do
      let(:platform) { 'other' }
      let(:locale) { 'sv' }

      it 'keeps the default locale path and generic MCP attribution' do
        expect(website.path).to eq('/listings/public-stay')
        expect(params).to include('utm_source' => 'mcp', 'utm_medium' => 'mcp')
      end
    end
  end
end
