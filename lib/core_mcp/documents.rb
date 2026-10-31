module CoreMcp::Documents
  DESTINATION = <<~GRAPHQL.freeze #: ::String
    query McpDestination($query: String, $id: ID, $locale: LocaleEnum!) {
      storedLocation(query: $query, id: $id) {
        id slug name(locale: $locale) type countryCode
      }
    }
  GRAPHQL

  CARD = <<~GRAPHQL.freeze #: ::String
    fragment McpStayCard on Listing {
      slug websiteUrl name(locale: $locale) summary(locale: $locale)
      ratingScore numReviews
      occupancy { numGuests numBedrooms numBeds petsAllowed }
      featuredAmenities { name(locale: $locale) }
      price(startDate: $startDate, endDate: $endDate, numGuests: $numGuests) @include(if: $includePrice) {
        currency startDate endDate unit cleaningFee
        discount { totalPrice price }
        calculatedGuestFees { name(locale: $locale) price }
        paymentSchedule { paymentDate from to discountedPrice cleaningFee }
      }
    }
  GRAPHQL

  SEARCH = <<~GRAPHQL.freeze #: ::String
    query McpSearch($filters: ListingFilter!, $page: Int!, $limit: Int!, $sortBy: ListingSortByEnum!,
                    $locale: LocaleEnum!, $startDate: ISO8601Date, $endDate: ISO8601Date,
                    $numGuests: Int!, $includePrice: Boolean!) {
      availableListings(filters: $filters, page: $page, limit: $limit, sortBy: $sortBy) {
        collection {
          ...McpStayCard
          previewImages(limit: 1) { url altText(locale: $locale) }
        }
        metadata { currentPage totalPages totalCount }
      }
    }
    #{CARD}
  GRAPHQL

  DETAILS = <<~GRAPHQL.freeze #: ::String
    query McpDetails($slug: String!, $locale: LocaleEnum!, $startDate: ISO8601Date, $endDate: ISO8601Date,
                     $numGuests: Int!, $includePrice: Boolean!) {
      showListing(slug: $slug) {
        ...McpStayCard
        previewImages(limit: 4) { url altText(locale: $locale) }
        cancellationPolicy(locale: $locale) houseRules(locale: $locale)
      }
    }
    #{CARD}
  GRAPHQL
end
