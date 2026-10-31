class CoreMcp::Tools::ResolveDestination < CoreMcp::Tools::Base
  KIND = 'resolve_destination'.freeze #: ::String

  tool_name KIND
  title 'Find destinations'
  description 'Find the Guestit destination for a place name before searching stays. Pass the place alone, such as Åre or Stockholm. ' \
    'Returns only places with Guestit stays, at most one. When nothing matches, ask the user about a larger place nearby.'
  input_schema CoreMcp::Tools::Schemas::DESTINATION_INPUT

  # @rbs (query: ::String, server_context: ::CoreMcp::server_context, ?locale: ::String) -> ::MCP::Tool::Response
  def self.call(query:, server_context:, locale: 'en')
    arguments = { query:, locale: }
    respond(server_context:, arguments:) { |catalog, inputs| catalog.resolve_destination(inputs) }
  end
end
