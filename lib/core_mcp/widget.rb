class CoreMcp::Widget < MCP::Resource
  URI = 'ui://guestit/stays-v1.html'.freeze #: ::String
  MIME_TYPE = 'text/html;profile=mcp-app'.freeze #: ::String
  TEMPLATE = ::File.read(::File.expand_path('../../assets/stays.html.erb', ::File.dirname(__FILE__))).freeze #: ::String
  LOGO = ::File.read(::File.expand_path('../../assets/logo.svg', ::File.dirname(__FILE__))).freeze #: ::String

  uri URI
  resource_name 'guestit_stays'
  title 'Guestit stays'
  description 'Explore and compare Guestit stays, then continue on Guestit to book.'
  mime_type MIME_TYPE

  # @rbs (server_context: ::CoreMcp::server_context) -> ::MCP::Resource::TextContents
  def self.contents(server_context:)
    config = server_context[:configuration] #: ::CoreMcp::Config
    configuration = ERB::Util.html_escape(JSON.generate(configuration(config)))
    title = ::I18n.t('core_mcp.stays.title', locale: :en)
    text = ERB.new(TEMPLATE).result_with_hash(configuration:, title:, logo: LOGO)
    csp = { connectDomains: [], resourceDomains: config.image_origins }
    metadata = { ui: { csp:, prefersBorder: false } }

    ::MCP::Resource::TextContents.new(uri: URI, mime_type: MIME_TYPE, text:, meta: metadata)
  end

  # @rbs (::CoreMcp::Config config) -> ::Hash[::Symbol, untyped]
  def self.configuration(config)
    {
      web_origin: config.web_origin,
      image_origins: config.image_origins,
      labels: {
        en: ::I18n.t('core_mcp.stays', locale: :en),
        sv: ::I18n.t('core_mcp.stays', locale: :sv)
      }
    }
  end
  private_class_method :configuration
end
