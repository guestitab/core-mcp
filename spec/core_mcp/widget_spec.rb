RSpec.describe CoreMcp::Widget do
  let(:web_origin) { 'https://localhost' }

  describe '.contents' do
    let(:configuration) do
      CoreMcp::Config.new(
        schema:,
        cache:,
        web_origin:,
        image_origins: ['https://localhost', 'https://images.example.net']
      )
    end

    it 'keeps configuration as escaped attribute data' do
      contents = described_class.contents(server_context:)
      document = Capybara.string(contents.text)
      data = JSON.parse(document.find('body', visible: :all)['data-configuration'])

      expect(data).to include('web_origin' => 'https://localhost', 'image_origins' => ['https://localhost', 'https://images.example.net'])
      expect(data.fetch('labels').keys).to contain_exactly('en', 'sv')
      expect(document).to have_css('svg[aria-label="Guestit"]', visible: :all)
    end

    context 'with quotes and markup in the configuration' do
      let(:web_origin) { 'https://localhost" data-injected="yes"><script>window.injected=true</script>' }

      it 'keeps the value inside the configuration attribute' do
        document = Capybara.string(described_class.contents(server_context:).text)
        data = JSON.parse(document.find('body', visible: :all)['data-configuration'])

        expect(data.fetch('web_origin')).to eq(web_origin)
        expect(document).to have_no_css('[data-injected]', visible: :all)
      end
    end
  end
end
