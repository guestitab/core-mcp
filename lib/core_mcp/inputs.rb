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

  private

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
