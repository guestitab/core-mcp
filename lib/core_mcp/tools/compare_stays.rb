class CoreMcp::Tools::CompareStays < CoreMcp::Tools::Base
  KIND = 'compare_stays'.freeze #: ::String

  tool_name KIND
  title 'Compare stays'
  description 'Compare two to four distinct Guestit listings for the same dates and number of guests. ' \
    'Retains missing or unavailable listings. Prices include applicable fees and do not hold inventory or confirm a booking.'
  input_schema CoreMcp::Tools::Schemas::COMPARE_INPUT
  meta ::MCP::Apps.tool_meta(resource_uri: CoreMcp::Widget::URI)

  # @rbs (server_context: ::CoreMcp::server_context, **untyped) -> ::MCP::Tool::Response
  def self.call(server_context:, **arguments)
    respond(server_context:, arguments:) { |catalog, inputs| catalog.compare_stays(inputs) }
  end
end
