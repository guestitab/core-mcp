module CoreMcp::Tools::Schemas
  TEXT = { type: 'string', minLength: 1, maxLength: 200 }.freeze #: ::Hash[::Symbol, untyped]
  DATE = {
    type: 'string',
    pattern: '^\\d{4}-\\d{2}-\\d{2}$',
    description: "YYYY-MM-DD. Supply both dates. Check-in must be within #{CoreMcp::Inputs::MAX_ADVANCE_DAYS} days " \
      "and the stay cannot exceed #{CoreMcp::Inputs::MAX_NIGHTS} nights."
  }.freeze #: ::Hash[::Symbol, untyped]
  LOCALE = { type: 'string', enum: %w[en sv], default: 'en' }.freeze #: ::Hash[::Symbol, untyped]
  GUESTS = { type: 'integer', minimum: 1, maximum: 100 }.freeze #: ::Hash[::Symbol, untyped]
  NULL_TEXT = { type: %w[string null] }.freeze #: ::Hash[::Symbol, untyped]
  NULL_NUMBER = { type: %w[number null] }.freeze #: ::Hash[::Symbol, untyped]
  NULL_INTEGER = { type: %w[integer null] }.freeze #: ::Hash[::Symbol, untyped]

  # @rbs (::Hash[::Symbol, untyped] properties, required: ::Array[::String]) -> ::Hash[::Symbol, untyped]
  def self.object(properties, required:)
    {
      type: 'object',
      properties:,
      required:,
      additionalProperties: false
    }
  end

  STAY_INPUT = {
    num_guests: GUESTS,
    start_date: DATE,
    end_date: DATE,
    locale: LOCALE
  }.freeze #: ::Hash[::Symbol, untyped]

  DESTINATION_INPUT = object(
    {
      query: { type: 'string', minLength: 2, maxLength: 120, pattern: '\\S.*\\S' },
      locale: LOCALE
    },
    required: %w[query]
  ).freeze #: ::Hash[::Symbol, untyped]

  SEARCH_INPUT = object(
    {
      **STAY_INPUT,
      location_id: { type: 'string', pattern: '^[0-9]+$', maxLength: 20 },
      with_pets: { type: 'boolean', default: false },
      min_bedrooms: { type: 'integer', minimum: 0, maximum: 100 },
      nightly_rate_min: { type: 'number', minimum: 0, maximum: 1_000_000, description: 'Minimum indexed average nightly rate in SEK. This is not an all-in stay total.' },
      nightly_rate_max: { type: 'number', minimum: 0, maximum: 1_000_000,
                          description: 'Maximum indexed average nightly rate in SEK. The final stay total includes the applicable fees.' },
      sort: { type: 'string', enum: %w[relevance price_asc price_desc], default: 'relevance' },
      page: { type: 'integer', minimum: 1, maximum: 20, default: 1 },
      limit: { type: 'integer', minimum: 1, maximum: 10, default: 5 }
    },
    required: %w[location_id num_guests]
  ).freeze #: ::Hash[::Symbol, untyped]

  DETAILS_INPUT = object(
    { **STAY_INPUT, listing_slug: TEXT },
    required: %w[listing_slug num_guests]
  ).freeze #: ::Hash[::Symbol, untyped]

  COMPARE_INPUT = object(
    {
      **STAY_INPUT,
      listing_slugs: { type: 'array', minItems: 2, maxItems: 4, uniqueItems: true, items: TEXT }
    },
    required: %w[listing_slugs num_guests start_date end_date]
  ).freeze #: ::Hash[::Symbol, untyped]

  PRICE = object(
    {
      status: { type: 'string', enum: %w[estimated unavailable dates_required] },
      currency: { type: 'string', enum: ['SEK'] },
      total_minor: NULL_INTEGER,
      unit: { type: %w[string null], enum: ['night', 'month', nil] },
      unit_price_minor: NULL_INTEGER,
      cleaning_fee_minor: NULL_INTEGER,
      guest_fees: {
        type: 'array',
        items: object({ name: { type: 'string' }, amount_minor: { type: 'integer' } }, required: %w[name amount_minor])
      },
      payment_schedule: {
        type: 'array',
        items: object(
          { payment_date: DATE, from: DATE, to: DATE, amount_minor: { type: 'integer' } },
          required: %w[payment_date from to amount_minor]
        )
      },
      inventory_held: { const: false },
      start_date: NULL_TEXT,
      end_date: NULL_TEXT
    },
    required: %w[status currency total_minor unit unit_price_minor cleaning_fee_minor guest_fees payment_schedule inventory_held start_date end_date]
  ).freeze #: ::Hash[::Symbol, untyped]

  LISTING = object(
    {
      status: { type: 'string', enum: %w[found not_found] },
      listing_slug: { type: 'string' },
      name: NULL_TEXT,
      summary: NULL_TEXT,
      website_url: NULL_TEXT,
      rating_score: NULL_NUMBER,
      num_reviews: NULL_INTEGER,
      cancellation_policy: NULL_TEXT,
      house_rules: NULL_TEXT,
      occupancy: {
        anyOf: [
          object(
            {
              num_guests: { type: 'integer' },
              num_bedrooms: { type: 'integer' },
              num_beds: { type: 'integer' },
              pets_allowed: { type: %w[boolean null] }
            },
            required: %w[num_guests num_bedrooms num_beds pets_allowed]
          ),
          { type: 'null' }
        ]
      },
      images: { type: 'array', maxItems: 4, items: object({ url: { type: 'string' }, alt_text: NULL_TEXT }, required: %w[url alt_text]) },
      amenities: { type: 'array', items: { type: 'string' } },
      price: PRICE
    },
    required: %w[status listing_slug name summary website_url rating_score num_reviews occupancy images amenities price]
  ).freeze #: ::Hash[::Symbol, untyped]

  OUTPUT = object(
    {
      view: { type: 'string', enum: %w[destinations search details compare] },
      locale: LOCALE,
      calculated_at: { type: 'string' },
      requested_stay: {
        anyOf: [
          object({ start_date: NULL_TEXT, end_date: NULL_TEXT, num_guests: GUESTS }, required: %w[start_date end_date num_guests]),
          { type: 'null' }
        ]
      },
      destinations: {
        type: 'array',
        maxItems: 10,
        items: object(
          {
            location_id: { type: 'string' },
            slug: { type: 'string' },
            name: { type: 'string' },
            country_code: { type: 'string' },
            type: { type: 'string' }
          },
          required: %w[location_id slug name country_code type]
        )
      },
      stays: { type: 'array', maxItems: 10, items: LISTING },
      pagination: {
        anyOf: [
          object(
            {
              page: { type: 'integer' },
              total_pages: { type: 'integer' },
              total_count: { type: 'integer', description: 'Indexed match count. May exceed currently public or bookable results; not a fresh inventory count.' }
            },
            required: %w[page total_pages total_count]
          ),
          { type: 'null' }
        ]
      },
      applied_filters: { anyOf: [SEARCH_INPUT, { type: 'null' }] }
    },
    required: %w[view locale calculated_at requested_stay destinations stays pagination applied_filters]
  ).freeze #: ::Hash[::Symbol, untyped]
end
