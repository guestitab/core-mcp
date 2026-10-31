class CoreMcp::Server
  TOOLS = [
    CoreMcp::Tools::ResolveDestination,
    CoreMcp::Tools::SearchStays,
    CoreMcp::Tools::StayDetails,
    CoreMcp::Tools::CompareStays
  ].freeze #: ::Array[singleton(::MCP::Tool)]
  ICON = {
    src: "data:image/png;base64,#{::Base64.strict_encode64(::File.binread(::File.expand_path('../../assets/icon.png', ::File.dirname(__FILE__))))}",
    mime_type: 'image/png',
    sizes: %w[180x180]
  }.freeze #: ::Hash[::Symbol, untyped]

  # @rbs (configuration: CoreMcp::Config) -> void
  def initialize(configuration:)
    @configuration = configuration
  end

  # @rbs (request: ::MCP::_HttpRequest, server_context: ::CoreMcp::request_context) -> ::CoreMcp::rack_response
  def call(request:, server_context:)
    capabilities = {
      tools: {},
      resources: {},
      extensions: ::MCP::Apps.capability
    }
    configuration = ::MCP::Configuration.new(
      exception_reporter: method(:report_error),
      validate_tool_call_results: true
    )
    server = ::MCP::Server.new(
      name: 'guestit',
      title: 'Guestit',
      version: '1.0.0',
      icons: [ICON],
      tools: TOOLS,
      resources: [CoreMcp::Widget],
      server_context: server_context.merge(configuration: @configuration),
      capabilities:,
      configuration:
    )
    transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(
      server,
      stateless: true,
      enable_json_response: true,
      serve_subscriptions_listen: false,
      max_request_bytes: 32 * 1024,
      allowed_hosts: @configuration.allowed_hosts
    )

    transport.handle_request(request)
  end

  private

  # @rbs (::Exception error, untyped context) -> void
  def report_error(error, context)
    return if error.is_a?(::MCP::Server::RequestHandlerError)

    @configuration.error_reporter.call(error, context)
  end
end
