class CoreMcp::Catalog
  RECORD_NOT_FOUND = 'record_not_found'.freeze #: ::String
  PROVIDER_RATE_LIMITED = 'provider_rate_limited'.freeze #: ::String
  INVALID_INPUT = 'invalid_input'.freeze #: ::String

  class QueryError < CoreMcp::Error; end

  # @rbs (server_context: CoreMcp::server_context) -> void
  def initialize(server_context:)
    configuration = server_context[:configuration] #: CoreMcp::Config

    @schema = configuration.schema
    @web_origin = configuration.web_origin
    @context = {
      current_guest_token: nil,
      current_guest_profile_id: nil,
      ip_address: server_context[:ip_address],
      user_agent: server_context[:user_agent]
    }
  end

  # @rbs (CoreMcp::Inputs inputs) -> CoreMcp::payload
  def resolve_destination(inputs)
    variables = { query: inputs.arguments.fetch(:query).strip, locale: inputs.locale }
    location = execute(CoreMcp::Documents::DESTINATION, variables).fetch('storedLocation')
    attributes = { destinations: location ? [destination(location)] : [] }

    response('destinations', inputs, attributes)
  end

  # @rbs (CoreMcp::Inputs inputs) -> CoreMcp::payload
  def search_stays(inputs)
    validate_destination!(inputs)

    result = execute(CoreMcp::Documents::SEARCH, inputs.search_variables).fetch('availableListings')
    listings = result.fetch('collection').map { |listing| Stay.new(data: listing, inputs:, web_origin: @web_origin) }
    stays = listings.reject(&:unavailable?).map(&:card)

    attributes = { stays:, requested_stay: inputs.stay, pagination: pagination(result.fetch('metadata')), applied_filters: inputs.arguments }

    response('search', inputs, attributes)
  end

  # @rbs (CoreMcp::Inputs inputs) -> CoreMcp::payload
  def stay_details(inputs)
    stays = public_stays([inputs.arguments.fetch(:listing_slug)], inputs)

    attributes = { stays:, requested_stay: inputs.stay }

    response('details', inputs, attributes)
  end

  # @rbs (CoreMcp::Inputs inputs) -> CoreMcp::payload
  def compare_stays(inputs)
    stays = public_stays(inputs.arguments.fetch(:listing_slugs), inputs)
    slugs = stays.map { |stay| stay.fetch(:listing_slug) }
    raise CoreMcp::ArgumentError, I18n.t('core_mcp.catalog.arguments.duplicate_stays', locale: :en) unless slugs.uniq.length == slugs.length

    attributes = { stays:, requested_stay: inputs.stay }

    response('compare', inputs, attributes)
  end

  private

  # @rbs (::String view, CoreMcp::Inputs inputs, ::Hash[::Symbol, untyped] attributes) -> CoreMcp::payload
  def response(view, inputs, attributes)
    {
      view:,
      locale: inputs.locale,
      calculated_at: ::Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
      requested_stay: nil,
      destinations: [],
      stays: [],
      pagination: nil,
      applied_filters: nil
    }.merge(attributes) #: CoreMcp::payload
  end

  # @rbs (CoreMcp::Inputs inputs) -> void
  def validate_destination!(inputs)
    destination_variables = { id: inputs.arguments.fetch(:location_id), locale: inputs.locale }
    destination = execute(CoreMcp::Documents::DESTINATION, destination_variables).fetch('storedLocation')

    raise CoreMcp::ArgumentError, I18n.t('core_mcp.catalog.arguments.destination_unknown', locale: :en) if destination.nil?
  end

  # @rbs (::Hash[::String, untyped] location) -> ::Hash[::Symbol, untyped]
  def destination(location)
    {
      location_id: location.fetch('id'),
      slug: location.fetch('slug'),
      name: location.fetch('name'),
      type: location.fetch('type'),
      country_code: location.fetch('countryCode')
    }
  end

  # @rbs (::Hash[::String, untyped] metadata) -> ::Hash[::Symbol, untyped]
  def pagination(metadata)
    {
      page: metadata.fetch('currentPage'),
      total_pages: metadata.fetch('totalPages'),
      total_count: metadata.fetch('totalCount')
    }
  end

  # @rbs (::String document, ::Hash[::Symbol, untyped] variables) -> ::Hash[::String, untyped]
  def execute(document, variables)
    result = @schema.execute(document, variables:, context: @context).to_h
    errors = result['errors']
    raise QueryError, query_error_message(errors, variables.fetch(:locale)) if errors && !errors.empty?

    result.fetch('data')
  end

  # @rbs (::Array[::String] slugs, CoreMcp::Inputs inputs) -> ::Array[CoreMcp::listing]
  def public_stays(slugs, inputs)
    queries = slugs.map { |slug| { query: CoreMcp::Documents::DETAILS, variables: inputs.listing_variables.merge(slug:), context: @context } }
    results = @schema.multiplex(queries, max_complexity: nil)

    slugs.zip(results).map do |slug, result|
      data = public_listing(result.to_h, inputs.locale)

      data ? Stay.new(data:, inputs:, web_origin: @web_origin).details : Stay.missing(slug)
    end
  end

  # @rbs (::Hash[::String, untyped] result, ::String locale) -> ::Hash[::String, untyped]?
  def public_listing(result, locale)
    errors = result['errors']
    return nil if errors && !errors.empty? && errors.all? { |error| error.dig('extensions', 'code') == RECORD_NOT_FOUND }
    raise QueryError, query_error_message(errors, locale) if errors && !errors.empty?

    result.fetch('data').fetch('showListing')
  end

  # @rbs (::Array[::Hash[::String, untyped]] errors, ::String locale) -> ::String
  def query_error_message(errors, locale)
    return I18n.t('core_mcp.catalog.busy', locale:) if errors.any? { |error| error.dig('extensions', 'code') == PROVIDER_RATE_LIMITED }
    return I18n.t('core_mcp.catalog.arguments.invalid_input', locale: :en) if errors.any? { |error| error.dig('extensions', 'code') == INVALID_INPUT }

    I18n.t('core_mcp.catalog.failed', locale:)
  end
end
