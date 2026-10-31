RSpec.shared_context 'with MCP configuration' do
  let(:schema) { double('GraphQL schema') }
  let(:cache) { double('Cache') }
  let(:configuration) do
    CoreMcp::Config.new(
      schema:,
      cache:,
      web_origin: 'https://localhost',
      image_origins: ['https://localhost']
    )
  end
  let(:server_context) do
    {
      ip_address: '192.0.2.1',
      user_agent: 'MCP test',
      ai_platform: nil,
      today: Date.new(2027, 2, 1),
      configuration:
    }
  end
end

RSpec.shared_context 'with catalog tools' do
  let(:catalog) { instance_double(CoreMcp::Catalog) }
  let(:quota) { instance_double(CoreMcp::Quota, spend!: nil) }

  before do
    allow(CoreMcp::Catalog).to receive(:new).and_return(catalog)
    allow(CoreMcp::Quota).to receive(:new).and_return(quota)
  end
end
