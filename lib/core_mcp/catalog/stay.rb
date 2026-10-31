class CoreMcp::Catalog::Stay
  WEBSITE_DEFAULT_LOCALE = 'sv'.freeze #: ::String

  # @rbs (data: ::Hash[::String, untyped], inputs: CoreMcp::Inputs, web_origin: ::String) -> void
  def initialize(data:, inputs:, web_origin:)
    @data = data
    @inputs = inputs
    @web_origin = web_origin
  end

  # @rbs () -> CoreMcp::listing
  def card
    {
      status: 'found',
      listing_slug: @data.fetch('slug'),
      name: @data.fetch('name'),
      summary: text('summary'),
      website_url:,
      rating_score: @data['ratingScore'],
      num_reviews: @data.fetch('numReviews'),
      occupancy:,
      images:,
      amenities: @data.fetch('featuredAmenities').map { |amenity| amenity.fetch('name') },
      price:
    }
  end

  # @rbs () -> CoreMcp::listing
  def details
    {
      **card,
      cancellation_policy: text('cancellationPolicy'),
      house_rules: text('houseRules')
    } #: CoreMcp::listing
  end

  # @rbs () -> bool
  def unavailable?
    @data.key?('price') && @data['price'].nil?
  end

  # @rbs (::String slug) -> CoreMcp::listing
  def self.missing(slug)
    {
      status: 'not_found',
      listing_slug: slug,
      name: nil,
      summary: nil,
      website_url: nil,
      rating_score: nil,
      num_reviews: nil,
      occupancy: nil,
      images: [],
      amenities: [],
      price: CoreMcp::Catalog::Price.empty('unavailable')
    }
  end

  private

  # @rbs () -> ::Array[::Hash[::Symbol, untyped]]
  def images
    @data.fetch('previewImages').map { |image| { url: image.fetch('url'), alt_text: image['altText'] } }
  end

  # @rbs () -> ::String
  def website_url
    url = ::URI.parse(@web_origin)
    url.path = "/listings/#{@data.fetch('slug')}"
    url.path = "/#{@inputs.locale}#{url.path}" unless @inputs.locale == WEBSITE_DEFAULT_LOCALE
    url.query = ::URI.encode_www_form(booking_params.sort_by { |key, _value| key.to_s })

    url.to_s
  end

  # @rbs () -> ::Hash[::Symbol, untyped]
  def booking_params
    {
      startDate: @inputs.arguments[:start_date],
      endDate: @inputs.arguments[:end_date],
      adults: @inputs.arguments.fetch(:num_guests)
    }.compact
  end

  # @rbs (::String key) -> ::String?
  def text(key)
    plain = ::Loofah.html5_fragment(@data[key].to_s).to_text
    text = ::Nokogiri::HTML.fragment(plain).text
                           .gsub(/[\p{Cc}\p{Cf}&&[^\n]]/, ' ')
                           .gsub(/[[:space:]&&[^\n]]+/, ' ')
                           .gsub(/ ?\n ?/, "\n")
                           .gsub(/\n{3,}/, "\n\n")
                           .strip

    text.empty? ? nil : text
  end

  # @rbs () -> ::Hash[::Symbol, untyped]
  def occupancy
    data = @data.fetch('occupancy')

    {
      num_guests: data.fetch('numGuests'),
      num_bedrooms: data.fetch('numBedrooms'),
      num_beds: data.fetch('numBeds'),
      pets_allowed: data['petsAllowed']
    }
  end

  # @rbs () -> CoreMcp::price
  def price
    return CoreMcp::Catalog::Price.empty('dates_required') unless @data.key?('price')
    return CoreMcp::Catalog::Price.empty('unavailable') if unavailable?

    CoreMcp::Catalog::Price.new(@data.fetch('price')).payload
  end
end
