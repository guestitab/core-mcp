RSpec.describe CoreMcp::Quota do
  subject(:spend) { described_class.new(server_context:).spend!(locale) }

  let(:locale) { 'en' }
  let(:counts) { Hash.new(0) }

  before do
    stub_const('CoreMcp::Quota::PER_CALLER', 2)
    stub_const('CoreMcp::Quota::TOTAL', 5)
    allow(cache).to receive(:increment).with(kind_of(String), 1, expires_in: 60) do |key, amount|
      counts[key] += amount
    end
  end

  describe '#spend!' do
    context 'without an AI platform' do
      before { 2.times { described_class.new(server_context:).spend!(locale) } }

      it 'refuses the client address past its allowance' do
        expect { spend }.to raise_error(CoreMcp::Error, 'Too many requests from this conversation. Try again in a minute.')
      end

      context 'with Swedish output' do
        let(:locale) { 'sv' }

        it 'uses the packaged Swedish refusal' do
          expect { spend }.to raise_error(CoreMcp::Error, 'För många förfrågningar från den här konversationen. Försök igen om en minut.')
        end
      end
    end

    context 'when ChatGPT names the user' do
      let(:server_context) { super().merge(ai_platform: 'openai', _meta: { 'openai/subject': 'v1/first' }) }
      let(:other_user) { server_context.merge(_meta: { 'openai/subject': 'v1/second' }) }

      before { 2.times { described_class.new(server_context:).spend!(locale) } }

      it 'counts each user on the shared address apart' do
        expect { spend }.to raise_error(CoreMcp::Error, 'Too many requests from this conversation. Try again in a minute.')
        expect { described_class.new(server_context: other_user).spend!(locale) }.not_to raise_error
      end
    end

    context 'when an AI platform names no user' do
      let(:server_context) { super().merge(ai_platform: 'anthropic') }

      before { 5.times { described_class.new(server_context:).spend!(locale) } }

      it 'applies only the total' do
        expect { spend }.to raise_error(CoreMcp::Error, 'Guestit is busy right now. Try again in a minute.')
      end
    end

    context 'with an untrusted user subject' do
      let(:server_context) { super().merge(_meta: { 'openai/subject': 'v1/first' }) }
      let(:other_subject) { server_context.merge(_meta: { 'openai/subject': 'v1/second' }) }

      before { 2.times { described_class.new(server_context:).spend!(locale) } }

      it 'keeps the caller inside the address allowance' do
        expect { described_class.new(server_context: other_subject).spend!(locale) }.to raise_error(CoreMcp::Error)
      end
    end
  end
end
