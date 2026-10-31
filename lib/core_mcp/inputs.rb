class CoreMcp::Inputs
  attr_reader :arguments #: ::CoreMcp::arguments

  MAX_NIGHTS = 730 #: ::Integer
  MAX_ADVANCE_DAYS = 730 #: ::Integer

  # @rbs (::CoreMcp::arguments args, today: ::Date) -> void
  def initialize(args, today:)
    @arguments = args
    @today = today

    validate_dates!
    validate_budget!
  end

  # @rbs () -> ::String
  def locale
    @arguments.fetch(:locale, 'en')
  end

  # @rbs () -> bool
  def dated?
    !@arguments[:start_date].nil?
  end

  # @rbs () -> ::CoreMcp::stay_input
  def stay
    {
      start_date: @arguments[:start_date],
      end_date: @arguments[:end_date],
      num_guests: @arguments.fetch(:num_guests)
    }
  end

  # @rbs () -> ::Hash[::Symbol, untyped]
  def listing_variables
    {
      locale:,
      startDate: @arguments[:start_date],
      endDate: @arguments[:end_date],
      numGuests: @arguments.fetch(:num_guests),
      includePrice: dated?
    }
  end

  # @rbs () -> ::Hash[::Symbol, untyped]
  def search_variables
    listing_variables.merge(
      filters:,
      page: @arguments.fetch(:page, 1),
      limit: @arguments.fetch(:limit, 5),
      sortBy: @arguments.fetch(:sort, 'relevance').upcase
    )
  end

  private

  # @rbs () -> ::Hash[::Symbol, untyped]
  def filters
    {
      locationId: @arguments.fetch(:location_id),
      occupancy:,
      availability:,
      price: budget
    }.compact
  end

  # @rbs () -> ::Hash[::Symbol, untyped]
  def occupancy
    {
      numGuests: @arguments.fetch(:num_guests),
      withPets: @arguments.fetch(:with_pets, false),
      numBedrooms: @arguments[:min_bedrooms]
    }.compact
  end

  # @rbs () -> ::Hash[::Symbol, untyped]
  def availability
    return {} unless dated?

    {
      startDate: @arguments.fetch(:start_date),
      endDate: @arguments.fetch(:end_date)
    }
  end

  # @rbs () -> ::Hash[::Symbol, untyped]?
  def budget
    return unless @arguments[:nightly_rate_min] || @arguments[:nightly_rate_max]

    {
      min: @arguments.fetch(:nightly_rate_min, 0),
      max: @arguments[:nightly_rate_max]
    }.compact
  end

  # @rbs () -> void
  def validate_dates!
    start_date = @arguments[:start_date]
    end_date = @arguments[:end_date]
    raise ::CoreMcp::ArgumentError, I18n.t('core_mcp.inputs.arguments.dates_incomplete', locale: :en) if start_date.nil? != end_date.nil?
    return unless start_date

    validate_period!(::Date.iso8601(start_date), ::Date.iso8601(end_date))
  rescue ::ArgumentError
    raise ::CoreMcp::ArgumentError, I18n.t('core_mcp.inputs.arguments.dates_invalid', locale: :en)
  end

  # @rbs (::Date from, ::Date to) -> void
  def validate_period!(from, to)
    raise ::CoreMcp::ArgumentError, I18n.t('core_mcp.inputs.arguments.check_in_past', locale: :en) if from < @today
    raise ::CoreMcp::ArgumentError, I18n.t('core_mcp.inputs.arguments.check_in_too_far', locale: :en, days: MAX_ADVANCE_DAYS) if from > @today + MAX_ADVANCE_DAYS
    raise ::CoreMcp::ArgumentError, I18n.t('core_mcp.inputs.arguments.check_out_order', locale: :en) unless to > from
    raise ::CoreMcp::ArgumentError, I18n.t('core_mcp.inputs.arguments.stay_too_long', locale: :en, nights: MAX_NIGHTS) if to - from > MAX_NIGHTS
  end

  # @rbs () -> void
  def validate_budget!
    minimum = @arguments[:nightly_rate_min]
    maximum = @arguments[:nightly_rate_max]

    return unless minimum && maximum
    raise ::CoreMcp::ArgumentError, I18n.t('core_mcp.inputs.arguments.budget_order', locale: :en) if maximum < minimum
  end
end
