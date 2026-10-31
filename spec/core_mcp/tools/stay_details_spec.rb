RSpec.describe CoreMcp::Tools::StayDetails do
  let(:arguments) { { listing_slug: 'public-listing', num_guests: 2, start_date: '2027-02-12', end_date: '2027-02-15' } }

  describe '.call' do
    {
      'with a partial stay' => { end_date: nil },
      'with a nonexistent calendar date' => { start_date: '2027-02-30' },
      'with a past date' => { start_date: '2026-12-31' },
      'with reversed dates' => { end_date: '2027-02-11' },
      'with an excessive booking horizon' => { start_date: '2030-02-12', end_date: '2030-02-15' },
      'with an excessive stay length' => { end_date: '2030-02-15' }
    }.each do |description, overrides|
      context description do
        let(:arguments) { super().merge(overrides) }

        it 'refuses the inputs before reading the catalog or spending a quota' do
          response = described_class.call(server_context:, **arguments)

          expect(response).to be_error
          expect(catalog_factory).not_to have_received(:new)
          expect(quota_factory).not_to have_received(:new)
        end
      end
    end

    context 'when the catalog refuses the request' do
      before { allow(catalog).to receive(:stay_details).and_raise(CoreMcp::Error, 'Try again later.') }

      it 'returns the expected refusal as a tool error' do
        response = described_class.call(server_context:, **arguments)

        expect(response).to be_error
        expect(response.to_h).to include(content: [{ type: 'text', text: 'Try again later.' }])
      end
    end
  end
end
