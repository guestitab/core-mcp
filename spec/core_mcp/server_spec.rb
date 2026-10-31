RSpec.describe CoreMcp::Server do
  subject(:response) { send_message }

  let(:server) { described_class.new(configuration:) }
  let(:host) { 'localhost' }
  let(:headers) do
    {
      'CONTENT_TYPE' => 'application/json',
      'HTTP_ACCEPT' => 'application/json, text/event-stream',
      'HTTP_MCP_PROTOCOL_VERSION' => '2025-11-25'
    }
  end
  let(:message) { { jsonrpc: '2.0', id: 1, method: 'tools/list' } }
  let(:body) { JSON.generate(message) }
  let(:result) { JSON.parse(response.body) }

  def send_message
    env = Rack::MockRequest.env_for("http://#{host}/mcp", method: 'POST', input: body, **headers, 'HTTP_HOST' => host)
    status, response_headers, response_body = server.call(request: Rack::Request.new(env), server_context:)

    Rack::MockResponse.new(status, response_headers, response_body)
  end

  describe '#call' do
    it 'discovers only the public catalog tools' do
      expect(response.status).to eq(200)
      expect(result.fetch('result').fetch('tools').map { |tool| tool.fetch('name') }).to contain_exactly(
        'resolve_destination', 'search_stays', 'stay_details', 'compare_stays'
      )
    end

    context 'when initializing' do
      let(:message) do
        super().merge(
          method: 'initialize',
          params: {
            protocolVersion: '2025-11-25',
            capabilities: {},
            clientInfo: { name: 'test', version: '1.0' }
          }
        )
      end

      it 'advertises the app without issuing a session' do
        expect(result.fetch('result')).to include(
          'serverInfo' => include('name' => 'guestit', 'icons' => [include('src' => start_with('data:image/png;base64,'))]),
          'capabilities' => include('extensions' => { 'io.modelcontextprotocol/ui' => { 'mimeTypes' => ['text/html;profile=mcp-app'] } })
        )
        expect(response.headers).not_to have_key('mcp-session-id')
      end
    end

    context 'with the modern stateless protocol' do
      let(:headers) { super().merge('HTTP_MCP_PROTOCOL_VERSION' => '2026-07-28', 'HTTP_MCP_METHOD' => 'tools/list') }
      let(:message) do
        super().merge(
          params: {
            _meta: {
              'io.modelcontextprotocol/protocolVersion' => '2026-07-28',
              'io.modelcontextprotocol/clientCapabilities' => {}
            }
          }
        )
      end

      it 'discovers tools without initializing a session' do
        expect(response.status).to eq(200)
        expect(result.dig('result', 'tools').size).to eq(4)
      end
    end

    context 'when reading the widget' do
      let(:message) { super().merge(method: 'resources/read', params: { uri: CoreMcp::Widget::URI }) }

      it 'returns the packaged HTML and allowed image origins' do
        expect(result.dig('result', 'contents')).to contain_exactly(
          include(
            'uri' => CoreMcp::Widget::URI,
            'text' => include('Guestit stays'),
            '_meta' => { 'ui' => { 'csp' => { 'connectDomains' => [], 'resourceDomains' => ['https://localhost'] }, 'prefersBorder' => false } }
          )
        )
      end
    end

    {
      'with an unknown tool' => ['tools/call', { name: 'delete_record', arguments: {} }],
      'with an unknown resource' => ['resources/read', { uri: 'file:///etc/passwd' }]
    }.each do |description, (method, params)|
      context description do
        let(:message) { super().merge(method:, params:) }

        it 'refuses the request before reading the catalog' do
          expect(result).to have_key('error')
          expect(catalog_factory).not_to have_received(:new)
        end
      end
    end

    context 'with private tool arguments' do
      let(:message) do
        super().merge(
          method: 'tools/call',
          params: { name: 'stay_details', arguments: { listing_slug: 'public', num_guests: 2, guest_profile_id: 42 } }
        )
      end

      it 'returns a tool refusal before reading the catalog' do
        expect(result.dig('result', 'isError')).to be(true)
        expect(catalog_factory).not_to have_received(:new)
      end
    end

    context 'with malformed JSON' do
      let(:body) { '{' }

      it 'returns the protocol parse error' do
        expect(result.dig('error', 'code')).to eq(-32_700)
      end
    end

    context 'with a JSON batch' do
      let(:body) { JSON.generate([message]) }

      it 'refuses the batch' do
        expect(result).to have_key('error')
      end
    end

    context 'with an oversized body' do
      let(:body) { 'x' * ((32 * 1024) + 1) }

      it 'rejects the body before parsing JSON' do
        expect(response.status).to eq(413)
      end
    end

    context 'with a foreign origin' do
      let(:headers) { super().merge('HTTP_ORIGIN' => 'https://example.net') }

      it 'refuses the origin' do
        expect(response.status).to eq(403)
      end
    end

    context 'with an unconfigured host' do
      let(:host) { 'example.net' }

      it 'refuses the host' do
        expect(response.status).to eq(403)
      end
    end

    context 'when calling the catalog' do
      let(:message) do
        super().merge(
          method: 'tools/call',
          params: {
            name: 'stay_details',
            arguments: { listing_slug: 'public', num_guests: 2 },
            _meta: { 'openai/subject' => 'user-1' }
          }
        )
      end
      let(:payload) do
        {
          view: 'details',
          locale: 'en',
          calculated_at: '2027-02-01T10:00:00Z',
          requested_stay: { start_date: nil, end_date: nil, num_guests: 2 },
          destinations: [],
          stays: [],
          pagination: nil,
          applied_filters: nil
        }
      end

      before { allow(catalog).to receive(:stay_details).and_return(payload) }

      it 'returns matching structured and text results' do
        expect(result.dig('result', 'structuredContent')).to eq(JSON.parse(JSON.generate(payload)))
        expect(JSON.parse(result.dig('result', 'content', 0, 'text'))).to eq(result.dig('result', 'structuredContent'))
      end

      it 'passes request metadata from the SDK to the host quota' do
        allow(quota_factory).to receive(:new) do |server_context:|
          expect(server_context[:_meta]).to include('openai/subject': 'user-1')
          expect(server_context[:ip_address]).to eq('192.0.2.1')
          quota
        end

        expect(response.status).to eq(200)
        expect(quota_factory).to have_received(:new)
      end

      context 'when another server has a different catalog' do
        let(:other_catalog) { double('Other catalog', stay_details: payload.merge(view: 'compare')) }
        let(:other_factory) { double('Other catalog factory', new: other_catalog) }
        let(:other_configuration) do
          CoreMcp::Config.new(catalog: other_factory, quota: quota_factory, web_origin: 'https://example.net', image_origins: [])
        end

        before { described_class.new(configuration: other_configuration) }

        it 'keeps the original server catalog' do
          expect(result.dig('result', 'structuredContent', 'view')).to eq('details')
          expect(other_catalog).not_to have_received(:stay_details)
        end
      end
    end
  end
end
