class CoreMcp::Tools::SearchStays < CoreMcp::Tools::Base
  KIND = 'search_stays'.freeze #: ::String

  tool_name KIND
  title 'Search stays'
  description 'Search public Guestit accommodation using a location_id from resolve_destination. Refine by resending the full filter set. ' \
    'Each stay is a short card; read house rules and the cancellation policy with stay_details or compare_stays before recommending one. ' \
    'Prices are estimates for the supplied dates and guests, with no inventory hold. ' \
    'Stays that fail the live check for those dates are left out, so a page can hold fewer than its limit. ' \
    'Nightly-rate filters use indexed average rates in SEK, not final stay totals. Pagination counts reflect the search index; current public rows may be fewer. ' \
    'Complete booking on the returned Guestit website link, which opens with the dates and guests filled in.'
  input_schema CoreMcp::Tools::Schemas::SEARCH_INPUT
  meta ::MCP::Apps.tool_meta(resource_uri: CoreMcp::Widget::URI)

  # @rbs (server_context: ::CoreMcp::server_context, **untyped) -> ::MCP::Tool::Response
  def self.call(server_context:, **arguments)
    respond(server_context:, arguments:) { |catalog, inputs| catalog.search_stays(inputs) }
  end
end
