# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Deprecation do
  after { WhittakerTech::Midas.reset_configuration! }

  describe '.warn' do
    let(:message) { 'SomeClass#old_method is deprecated. Use SomeClass#new_method instead.' }

    context 'when deprecation_behavior is :warn (default)' do
      before { WhittakerTech::Midas.deprecation_behavior = :warn }

      it 'calls Kernel.warn with a formatted message' do
        allow(Kernel).to receive(:warn)
        described_class.warn(message)
        expect(Kernel).to have_received(:warn).with(
          a_string_including('[DEPRECATED]', message, described_class::HORIZON)
        )
      end

      it 'returns nil' do
        allow(Kernel).to receive(:warn)
        expect(described_class.warn(message)).to be_nil
      end
    end

    context 'when deprecation_behavior is :raise' do
      before { WhittakerTech::Midas.deprecation_behavior = :raise }

      it 'raises a DeprecationError' do
        expect { described_class.warn(message) }
          .to raise_error(described_class::DeprecationError)
      end

      it 'includes the message in the error' do
        expect { described_class.warn(message) }
          .to raise_error(described_class::DeprecationError, a_string_including(message))
      end

      it 'includes the HORIZON version in the error' do
        expect { described_class.warn(message) }
          .to raise_error(described_class::DeprecationError,
                          a_string_including(described_class::HORIZON))
      end

      it 'includes callsite information in the error' do
        expect { described_class.warn(message) }
          .to raise_error(described_class::DeprecationError, a_string_including('called from'))
      end
    end

    context 'when deprecation_behavior is :silence' do
      before { WhittakerTech::Midas.deprecation_behavior = :silence }

      it 'does not call Kernel.warn' do
        allow(Kernel).to receive(:warn)
        described_class.warn(message)
        expect(Kernel).not_to have_received(:warn)
      end

      it 'does not raise' do
        expect { described_class.warn(message) }.not_to raise_error
      end

      it 'returns nil' do
        expect(described_class.warn(message)).to be_nil
      end
    end

    context 'with an explicit callsite' do
      before { WhittakerTech::Midas.deprecation_behavior = :raise }

      it 'uses the provided callsite location' do
        fake_location = instance_double(Thread::Backtrace::Location,
                                        path: '/app/foo.rb',
                                        lineno: 42)
        expect { described_class.warn(message, fake_location) }
          .to raise_error(described_class::DeprecationError,
                          a_string_including('/app/foo.rb:42'))
      end

      it 'handles a nil callsite gracefully' do
        expect { described_class.warn(message, nil) }
          .to raise_error(described_class::DeprecationError,
                          a_string_including('unknown'))
      end
    end
  end

  describe 'HORIZON' do
    it 'is the removal version string' do
      expect(described_class::HORIZON).to eq('0.3.0')
    end
  end

  describe 'DeprecationError' do
    it 'is a StandardError subclass' do
      expect(described_class::DeprecationError.ancestors).to include(StandardError)
    end
  end
end
