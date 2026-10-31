class CoreMcp::Tools::StayDetails < CoreMcp::Tools::Base
  KIND = 'stay_details'.freeze #: ::String

  tool_name KIND
  title 'Stay details'
  description 'Read a public Guestit listing, house rules, cancellation policy and dated price estimate. Supply both dates and the guest count for an estimate. ' \
    'Fees shown are already included in the total. This does not reserve inventory or take payment. ' \
    'Open website_url to continue on Guestit; it opens with the dates and guests filled in.'
  input_schema CoreMcp::Tools::Schemas::DETAILS_INPUT
  meta ::MCP::Apps.tool_meta(resource_uri: CoreMcp::Widget::URI)

  # @rbs (server_context: ::CoreMcp::server_context, **untyped) -> ::MCP::Tool::Response
  def self.call(server_context:, **arguments)
    respond(server_context:, arguments:) { |catalog, inputs| catalog.stay_details(inputs) }
  end
end
