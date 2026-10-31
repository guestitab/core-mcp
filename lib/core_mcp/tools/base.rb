class CoreMcp::Tools::Base < MCP::Tool
  # @rbs (singleton(::CoreMcp::Tools::Base) subclass) -> void
  def self.inherited(subclass)
    super

    hints = {
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: false
    }
    subclass.annotations(hints)
    subclass.output_schema(CoreMcp::Tools::Schemas::OUTPUT)
  end

  # @rbs (server_context: ::CoreMcp::server_context, arguments: ::CoreMcp::arguments) { (::CoreMcp::_Catalog, ::CoreMcp::Inputs) -> ::CoreMcp::payload } -> ::MCP::Tool::Response
  def self.respond(server_context:, arguments:)
    configuration = server_context[:configuration] #: ::CoreMcp::Config
    inputs = CoreMcp::Inputs.new(arguments, today: server_context[:today])
    configuration.quota.new(server_context:).spend!(inputs.locale)
    catalog = configuration.catalog.new(server_context:)
    payload = yield(catalog, inputs)
    content = [{ type: 'text', text: JSON.generate(payload) }]

    ::MCP::Tool::Response.new(content, structured_content: payload)
  rescue CoreMcp::Error => e
    content = [{ type: 'text', text: e.message }]

    ::MCP::Tool::Response.new(content, error: true)
  end
end
