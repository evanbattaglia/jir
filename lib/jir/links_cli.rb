module Jir
  class LinksCLI < BaseCLI
    def link
      link_type_id, _link_type_name, direction = lookup_link_type_id_direction(args.verb)
      ticket2_key = ticket_key(args.ticket2_key)
      request = {
        type: {id: link_type_id},
        inwardIssue: {key: direction == :inward ? ticket2_key : ticket_key},
        outwardIssue: {key: direction == :outward ? ticket2_key : ticket_key}
      }
      request[:comment] = {body: flags.comment} if flags.comment
      jira "issueLink", "--raw %s", [request.to_json], method: :post
    end

    def lookup_link_type_id_direction(verb)
      matches = verb_lookup_table[verb]&.sort
      if !matches
        raise "Unknown link type #{args.verb.inspect}. Expected one of: #{verb_to_link_type_id_direction_lookup_table.keys.inspect}"
      end

      if matches.length > 1
        STDERR.puts "Warning: Ambiguous link type #{args.verb.inspect}. Matches: #{matches.inspect}. Using first match."
      end

      matches.first
    end

    # Maps verb => array of [link_type_id, direction] for all possible matches
    def verb_lookup_table
      @verb_lookup_table ||= {}.tap do |lookup_table|
        jira_json("issueLinkType", dry_run: false)['issueLinkTypes'].each do |link|
          (lookup_table[link['inward']] ||= []) << [link['id'], link['name'], :inward]
          (lookup_table[link['outward']] ||= []) << [link['id'], link['name'], :outward]
        end
      end
    end
  end
end

