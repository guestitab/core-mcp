RSpec.describe CoreMcp::Catalog::Stay do
  subject(:details) { described_class.new(data:, inputs:).details }

  let(:inputs) do
    CoreMcp::Inputs.new(
      { listing_slug: 'stockholm-stay', num_guests: 2, start_date: '2027-02-12', end_date: '2027-02-15', locale: 'en' },
      today: server_context[:today]
    )
  end
  let(:data) do
    {
      'slug' => 'stockholm-stay',
      'websiteUrl' => 'https://localhost/listings/stockholm-stay',
      'name' => 'Stockholm stay',
      'summary' => '<div>First room.</div><div>Second&nbsp;room.</div>',
      'numReviews' => 2,
      'occupancy' => { 'numGuests' => 4, 'numBedrooms' => 1, 'numBeds' => 2, 'petsAllowed' => false },
      'previewImages' => [{ 'url' => 'https://localhost/stay.jpg', 'altText' => 'Living room' }],
      'featuredAmenities' => [{ 'name' => 'WiFi' }],
      'houseRules' => '<div>No smoking.<br>Quiet&nbsp;after 22.</div>',
      'price' => {
        'discount' => { 'totalPrice' => 375, 'price' => 100 },
        'currency' => 'SEK',
        'unit' => 'night',
        'cleaningFee' => 75,
        'startDate' => '2027-02-12',
        'endDate' => '2027-02-15',
        'calculatedGuestFees' => [{ 'name' => 'Cleaning', 'price' => 75 }],
        'paymentSchedule' => [{ 'paymentDate' => '2027-02-01', 'from' => '2027-02-12', 'to' => '2027-02-15', 'discountedPrice' => 300, 'cleaningFee' => 75 }]
      }
    }
  end

  describe '#details' do
    it 'cleans markup and maps the full quote into minor units' do
      expect(details).to include(
        summary: "First room.\n\nSecond room.",
        house_rules: "No smoking.\nQuiet after 22.",
        website_url: 'https://localhost/en/listings/stockholm-stay?adults=2&endDate=2027-02-15&startDate=2027-02-12',
        price: include(
          total_minor: 37_500,
          unit_price_minor: 10_000,
          cleaning_fee_minor: 7500,
          inventory_held: false,
          guest_fees: [{ name: 'Cleaning', amount_minor: 7500 }],
          payment_schedule: [include(amount_minor: 37_500)]
        )
      )
    end

    context 'without dates' do
      let(:data) { super().except('price') }

      it 'does not invent a price' do
        expect(details.fetch(:price)).to include(status: 'dates_required', total_minor: nil, inventory_held: false)
      end
    end

    context 'with an unavailable price' do
      let(:data) { super().merge('price' => nil) }

      it 'keeps the stay without an estimate' do
        expect(details).to include(status: 'found', price: include(status: 'unavailable', total_minor: nil))
      end
    end
  end
end
