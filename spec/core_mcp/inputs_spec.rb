RSpec.describe CoreMcp::Inputs do
  subject(:inputs) { described_class.new(arguments, today: Date.new(2027, 2, 1)) }

  let(:arguments) { { num_guests: 2, start_date: '2027-02-12', end_date: '2027-02-15' } }

  describe '#stay' do
    it 'carries the requested dates and guests' do
      expect(inputs.stay).to eq(arguments)
    end

    context 'without dates' do
      let(:arguments) { { num_guests: 2 } }

      it 'keeps the absent dates and defaults to English' do
        expect(inputs.stay).to eq(start_date: nil, end_date: nil, num_guests: 2)
        expect(inputs.locale).to eq('en')
        expect(inputs).not_to be_dated
      end
    end

    context 'with the Swedish locale' do
      let(:arguments) { super().merge(locale: 'sv') }

      it 'keeps the requested language' do
        expect(inputs.locale).to eq('sv')
      end
    end
  end

  describe 'input refusals' do
    {
      'with a partial stay' => [{ end_date: nil }, 'Choose both a check-in and a check-out date.'],
      'with a nonexistent date' => [{ start_date: '2027-02-30' }, 'Dates must be real calendar dates in YYYY-MM-DD format.'],
      'with a past date' => [{ start_date: '2027-01-31' }, 'Check-in must be today or later.'],
      'with reversed dates' => [{ end_date: '2027-02-11' }, 'Check-out must be after check-in.'],
      'with an excessive booking horizon' => [{ start_date: '2030-02-12', end_date: '2030-02-15' }, 'Check-in must be within the next 730 days.'],
      'with an excessive stay length' => [{ end_date: '2030-02-15' }, 'A stay can be at most 730 nights.'],
      'with a reversed budget' => [{ nightly_rate_min: 200, nightly_rate_max: 100 }, 'The maximum nightly rate must be at least the minimum.']
    }.each do |description, (overrides, message)|
      context description do
        let(:arguments) { super().merge(overrides) }

        it 'refuses the inputs with a traveler message' do
          expect { inputs }.to raise_error(CoreMcp::ArgumentError, message)
        end
      end
    end

    context 'when the host defaults to Swedish' do
      let(:arguments) { super().merge(end_date: nil) }

      it 'keeps argument refusals in English' do
        I18n.with_locale(:sv) do
          expect { inputs }.to raise_error(CoreMcp::ArgumentError, 'Choose both a check-in and a check-out date.')
        end
      end
    end

    context 'with check-in on the host current date' do
      let(:arguments) { super().merge(start_date: '2027-02-01') }

      it 'accepts the host calendar day' do
        expect(inputs).to be_dated
      end
    end
  end
end
