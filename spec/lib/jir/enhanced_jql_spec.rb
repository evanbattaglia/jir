require_relative '../../../lib/jir/jql'

RSpec.describe Jir::Jql do
  describe '.join_queries_and_shift_args' do
    it 'joins simple queries without arguments' do
      queries = ['status = Open', 'project = TEST']
      result = described_class.join_queries_and_shift_args(queries)
      expect(result).to eq('(status = Open) AND (project = TEST)')
    end

    it 'joins queries with arguments and shifts them correctly' do
      queries = ['assignee = %1', 'project = %1 AND status = %2']
      result = described_class.join_queries_and_shift_args(queries)
      expect(result).to eq('(assignee = %1) AND (project = %2 AND status = %3)')
    end

    it 'handles complex argument shifting' do
      queries = [
        'field1 = %1 AND field2 = %2',
        'field3 = %1',
        'field4 = %1 AND field5 = %2 AND field6 = %3'
      ]
      result = described_class.join_queries_and_shift_args(queries)
      expected = '(field1 = %1 AND field2 = %2) AND (field3 = %3) AND (field4 = %4 AND field5 = %5 AND field6 = %6)'
      expect(result).to eq(expected)
    end

    it 'filters out nil queries' do
      queries = ['status = Open', nil, 'project = TEST']
      result = described_class.join_queries_and_shift_args(queries)
      expect(result).to eq('(status = Open) AND (project = TEST)')
    end

    it 'handles empty array' do
      result = described_class.join_queries_and_shift_args([])
      expect(result).to eq('')
    end

    it 'handles single query' do
      result = described_class.join_queries_and_shift_args(['status = Open'])
      expect(result).to eq('(status = Open)')
    end
  end

  describe '.shift_query_args' do
    it 'shifts all argument numbers by offset' do
      query = 'field1 = %1 AND field2 = %2 AND field3 = %3'
      result = described_class.shift_query_args(query, 5)
      expect(result).to eq('field1 = %6 AND field2 = %7 AND field3 = %8')
    end

    it 'handles queries without arguments' do
      query = 'status = Open'
      result = described_class.shift_query_args(query, 3)
      expect(result).to eq('status = Open')
    end

    it 'handles raw arguments with r suffix' do
      query = 'field = %1r AND other = %2'
      result = described_class.shift_query_args(query, 2)
      expect(result).to eq('field = %3r AND other = %4')
    end
  end

  describe '.n_args_in_query' do
    it 'returns highest argument number in query' do
      query = 'field1 = %1 AND field2 = %3 AND field3 = %2'
      expect(described_class.n_args_in_query(query)).to eq(3)
    end

    it 'returns 0 for query without arguments' do
      query = 'status = Open AND project = TEST'
      expect(described_class.n_args_in_query(query)).to eq(0)
    end

    it 'handles single argument' do
      query = 'assignee = %1'
      expect(described_class.n_args_in_query(query)).to eq(1)
    end

    it 'handles raw and separator suffixes' do
      query = 'field1 = %2r AND field2 = %1s AND field3 = %3'
      expect(described_class.n_args_in_query(query)).to eq(3)
    end

    it 'handles double-digit arguments' do
      query = 'field = %12'
      expect(described_class.n_args_in_query(query)).to eq(12)
    end
  end

  describe '#render' do
    context 'with correct number of arguments' do
      it 'renders simple arguments with JSON quoting' do
        jql = described_class.new('assignee = %1 AND status = %2')
        result = jql.render(['john.doe', 'Open'])
        expect(result).to eq('assignee = "john.doe" AND status = "Open"')
      end

      it 'renders raw arguments without JSON quoting' do
        jql = described_class.new('field = %1r AND other = %2')
        result = jql.render(['raw_value', 'quoted_value'])
        expect(result).to eq('field = raw_value AND other = "quoted_value"')
      end

      it 'handles separator suffix' do
        jql = described_class.new('field = %1sr')
        result = jql.render(['value'])
        expect(result).to eq('field = "value"r')
      end

      it 'handles mixed raw and regular arguments' do
        jql = described_class.new('raw_field IN (%1r) AND quoted_field = %2')
        result = jql.render(['(1,2,3)', 'test'])
        expect(result).to eq('raw_field IN ((1,2,3)) AND quoted_field = "test"')
      end

      it 'handles escaped percent signs' do
        jql = described_class.new('field = %%discount%% AND assignee = %1')
        result = jql.render(['user'])
        expect(result).to eq('field = %discount% AND assignee = "user"')
      end

      it 'handles complex escaped patterns' do
        jql = described_class.new('text ~ "%%%1%%" AND status = %2')
        result = jql.render(['search', 'Done'])
        expect(result).to eq('text ~ "%"search"%" AND status = "Done"')
      end

      it 'handles arguments that need JSON escaping' do
        jql = described_class.new('summary ~ %1')
        result = jql.render(['text with "quotes" and \backslashes'])
        expect(result).to eq('summary ~ "text with \\"quotes\\" and \\\\backslashes"')
      end
    end

    context 'with wrong number of arguments' do
      it 'raises error when too few arguments provided' do
        jql = described_class.new('field1 = %1 AND field2 = %2')
        expect {
          jql.render(['only_one'])
        }.to raise_error(Jir::Jql::WrongNumberOfArgs, /requires 2 arguments, got 1/)
      end

      it 'raises error when too many arguments provided' do
        jql = described_class.new('field = %1')
        expect {
          jql.render(['arg1', 'arg2', 'arg3'])
        }.to raise_error(Jir::Jql::WrongNumberOfArgs, /requires 1 arguments, got 3/)
      end

      it 'includes helpful error information' do
        jql = described_class.new('test = %1')
        expect {
          jql.render([])
        }.to raise_error(Jir::Jql::WrongNumberOfArgs, /Arguments: \[\].*Query: test = %1/)
      end
    end

    context 'with no arguments needed' do
      it 'renders query without placeholders' do
        jql = described_class.new('status = Open')
        result = jql.render([])
        expect(result).to eq('status = Open')
      end

      it 'handles escaped percent signs in no-arg query' do
        jql = described_class.new('field LIKE "%%pattern%%"')
        result = jql.render([])
        expect(result).to eq('field LIKE "%pattern%"')
      end
    end

    context 'edge cases' do
      it 'handles empty string arguments' do
        jql = described_class.new('field = %1')
        result = jql.render([''])
        expect(result).to eq('field = ""')
      end

      it 'handles numeric arguments' do
        jql = described_class.new('field = %1')
        result = jql.render([42])
        expect(result).to eq('field = 42')
      end

      it 'handles arguments that are arrays' do
        jql = described_class.new('field = %1')
        result = jql.render([['a', 'b']])
        expect(result).to eq('field = ["a","b"]')
      end

      it 'handles hash arguments' do
        jql = described_class.new('field = %1')
        result = jql.render([{key: 'value'}])
        expect(result).to eq('field = {"key":"value"}')
      end
    end
  end

  describe 'integration examples' do
    it 'works with real-world JIRA query patterns' do
      jql = described_class.new('project = %1 AND assignee = %2 AND status IN (%3r)')
      result = jql.render(['MYPROJ', 'john.doe', '"Open", "In Progress"'])
      expect(result).to eq('project = "MYPROJ" AND assignee = "john.doe" AND status IN ("Open", "In Progress")')
    end

    it 'handles complex text search with escaping' do
      jql = described_class.new('summary ~ %1 AND description ~ "%%prefix%% %2"')
      result = jql.render(['bug', 'critical'])
      expect(result).to eq('summary ~ "bug" AND description ~ "%prefix% "critical""')
    end

    it 'works with date queries using raw arguments' do
      jql = described_class.new('created >= %1r AND updated <= %2r')
      result = jql.render(['-1w', 'now()'])
      expect(result).to eq('created >= -1w AND updated <= now()')
    end
  end
end
