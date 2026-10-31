RSpec.shared_context 'with MCP configuration' do
  let(:catalog) { double('Catalog') }
  let(:quota) { double('Quota', spend!: nil) }
  let(:catalog_factory) { double('Catalog factory', new: catalog) }
  let(:quota_factory) { double('Quota factory', new: quota) }
  let(:configuration) do
    CoreMcp::Config.new(
      catalog: catalog_factory,
      quota: quota_factory,
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
