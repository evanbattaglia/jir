require_relative '../../../lib/jir/field_types'

RSpec.describe Jir::FieldTypes do
  describe '.resolve_aliases' do
    before do
      allow(Jir::Config).to receive(:aliases).and_return({
        'users' => { 'me' => 'john.doe@example.com', 'boss' => 'jane.smith@example.com' },
        'priorities' => { 'high' => 'Critical', 'low' => 'Minor' }
      })
    end

    it 'returns original value when no aliases_type' do
      expect(described_class.resolve_aliases(nil, 'me')).to eq('me')
    end

    it 'returns original value when alias not found' do
      expect(described_class.resolve_aliases('users', 'unknown')).to eq('unknown')
    end

    it 'resolves alias when found' do
      expect(described_class.resolve_aliases('users', 'me')).to eq('john.doe@example.com')
      expect(described_class.resolve_aliases('priorities', 'high')).to eq('Critical')
    end
  end

  describe '.field_values_array' do
    before do
      allow(Jir::Config).to receive(:user).with('john').and_return('acc-123')
      allow(Jir::Config).to receive(:user).with('jane').and_return('acc-456')
      allow(Jir::Config).to receive(:aliases).and_return(nil)
    end

    context 'with user_list type' do
      it 'converts user names to account objects' do
        result = described_class.field_values_array(
          type: :user_list,
          aliases_type: nil,
          values: ['john', 'jane']
        )
        expect(result).to eq([
          { accountId: 'acc-123' },
          { accountId: 'acc-456' }
        ])
      end

      it 'handles empty array special case' do
        result = described_class.field_values_array(
          type: :user_list,
          aliases_type: nil,
          values: ['']
        )
        expect(result).to eq([])
      end
    end

    context 'with string_list type' do
      it 'returns strings as-is' do
        result = described_class.field_values_array(
          type: :string_list,
          aliases_type: nil,
          values: ['foo', 'bar']
        )
        expect(result).to eq(['foo', 'bar'])
      end
    end

    context 'with unknown type' do
      it 'returns nil' do
        result = described_class.field_values_array(
          type: :unknown_type,
          aliases_type: nil,
          values: ['foo']
        )
        expect(result).to be_nil
      end
    end
  end

  describe '.field_values_json' do
    before do
      allow(Jir::TicketKeyResolver).to receive(:ticket_key).with('PROJ-123').and_return('PROJ-123')
      allow(Jir::Config).to receive(:aliases).and_return(nil)
    end

    context 'with single value string converters' do
      it 'converts raw type' do
        result = described_class.field_values_json(
          type: :raw,
          aliases_type: nil,
          values: ['unquoted']
        )
        expect(result).to eq('unquoted')
      end

      it 'converts string type to JSON' do
        result = described_class.field_values_json(
          type: :string,
          aliases_type: nil,
          values: ['hello world']
        )
        expect(result).to eq('"hello world"')
      end

      it 'converts object_keyed_by_name type' do
        result = described_class.field_values_json(
          type: :object_keyed_by_name,
          aliases_type: nil,
          values: ['username']
        )
        expect(result).to eq('{"name":"username"}')
      end

      it 'converts object_keyed_by_key type' do
        result = described_class.field_values_json(
          type: :object_keyed_by_key,
          aliases_type: nil,
          values: ['some-key']
        )
        expect(result).to eq('{"key":"some-key"}')
      end

      it 'converts ticket type' do
        result = described_class.field_values_json(
          type: :ticket,
          aliases_type: nil,
          values: ['PROJ-123']
        )
        expect(result).to eq('{"key":"PROJ-123"}')
      end
    end

    context 'with array converters' do
      before do
        allow(Jir::Config).to receive(:user).with('john').and_return('acc-123')
        allow(Jir::Config).to receive(:user).with('jane').and_return('acc-456')
      end

      it 'converts user_list to JSON array' do
        result = described_class.field_values_json(
          type: :user_list,
          aliases_type: nil,
          values: ['john', 'jane']
        )
        expect(result).to eq('[{"accountId":"acc-123"},{"accountId":"acc-456"}]')
      end

      it 'converts string_list to JSON array' do
        result = described_class.field_values_json(
          type: :string_list,
          aliases_type: nil,
          values: ['foo', 'bar']
        )
        expect(result).to eq('["foo","bar"]')
      end
    end

    context 'with aliases' do
      before do
        allow(Jir::Config).to receive(:aliases).and_return({
          'users' => { 'me' => 'john.doe' }
        })
      end

      it 'resolves aliases before conversion' do
        result = described_class.field_values_json(
          type: :string,
          aliases_type: 'users',
          values: ['me']
        )
        expect(result).to eq('"john.doe"')
      end
    end

    context 'with unknown type' do
      it 'raises an error' do
        expect {
          described_class.field_values_json(
            type: :unknown_type,
            aliases_type: nil,
            values: ['foo']
          )
        }.to raise_error(/No type converter available for type unknown_type/)
      end
    end
  end
end
