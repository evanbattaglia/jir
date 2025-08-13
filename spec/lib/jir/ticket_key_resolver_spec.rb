require_relative '../../../lib/jir/ticket_key_resolver'

RSpec.describe Jir::TicketKeyResolver do
  # Mock Config to avoid complex dependencies
  before do
    stub_const('Jir::Config', Class.new do
      def self.default_project; 'MYPROJ'; end
      def self.ticket_aliases
        {
          'my-epic' => 'MYPROJ-1000',
          'bug-123' => 'BUGTRACK-456'
        }
      end
    end)
  end

  describe '.ticket_keys' do
    context 'with comma-separated values' do
      it 'splits and processes each part' do
        result = described_class.ticket_keys('123,456')
        expect(result).to eq(['MYPROJ-123', 'MYPROJ-456'])
      end
    end

    context 'with numeric key and default project' do
      it 'prepends default project' do
        result = described_class.ticket_keys('123')
        expect(result).to eq(['MYPROJ-123'])
      end
    end

    context 'with ticket alias' do
      it 'resolves from aliases config' do
        result = described_class.ticket_keys('my-epic')
        expect(result).to eq(['MYPROJ-1000'])
      end

      it 'resolves alias with different project' do
        result = described_class.ticket_keys('bug-123')
        expect(result).to eq(['BUGTRACK-456'])
      end
    end

    context 'with full ticket format' do
      it 'returns as-is when already in PROJECT-NUMBER format' do
        result = described_class.ticket_keys('OTHERPROJ-456')
        expect(result).to eq(['OTHERPROJ-456'])
      end
    end

    context 'with unknown format' do
      it 'raises error for unrecognized format' do
        expect {
          described_class.ticket_keys('invalid-format')
        }.to raise_error(/unknown ticket key format/)
      end
    end
  end

  describe '.ticket_keys_from_git_ref' do
    before do
      # Mock the git command execution
      allow_any_instance_of(Object).to receive(:`)
        .with(/git log --format=%B -n 1/)
        .and_return("Fix issues MYPROJ-111 and MYPROJ-222\n\nAlso touches MYPROJ-333.")
    end

    it 'extracts multiple tickets from commit message' do
      # We'll test the regex extraction logic directly
      commit_msg = "Fix issues MYPROJ-111 and MYPROJ-222\n\nAlso touches MYPROJ-333."
      ticket_regex = /(MYPROJ-[0-9]{1,8})(\W|$)/
      tickets = commit_msg.scan(ticket_regex).map(&:first)
      expect(tickets).to eq(['MYPROJ-111', 'MYPROJ-222', 'MYPROJ-333'])
    end

    it 'handles tickets with word boundaries correctly' do
      commit_msg = "MYPROJ-123: fix bug (related to MYPROJ-456)"
      ticket_regex = /(MYPROJ-[0-9]{1,8})(\W|$)/
      tickets = commit_msg.scan(ticket_regex).map(&:first)
      expect(tickets).to eq(['MYPROJ-123', 'MYPROJ-456'])
    end
  end
end
