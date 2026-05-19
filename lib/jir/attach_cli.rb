require_relative 'base_cli'

module Jir
  class AttachCLI < BaseCLI
    def main
      filenames = args.filenames
      file_placeholders = filenames.map { "file@%s" }.join(" ")
      jira(
        "issue/#{ticket_key}/attachments",
        "%s #{file_placeholders}",
        ["X-Atlassian-Token: nocheck"] + filenames,
        extra_before: '--form',
        method: :post,
        api_version_3: true
      )
    end

    def download
      _download(args.attachment_id)
    end

    def _download(id)
      jira(
        "attachment/content/#{id}",
        extra_before: "--follow --download",
        api_version_3: true,
      )
    end

    def download_all
      jira_json_each_page("issue/#{ticket_key}?fields=attachment") do |json|
        json&.dig("fields", "attachment")&.each do |attachment|
          _download(attachment["id"])
        end
      end
    end

    def delete
      args.attachment_ids.each { |id| _delete(id) }
    end

    def _delete(id)
      jira(
        "attachment/#{id}",
        "%s",
        ["X-Atlassian-Token: nocheck"],
        method: :delete,
        api_version_3: true,
      )
    end

    def delete_all
      ids = []
      jira_json_each_page("issue/#{ticket_key}?fields=attachment") do |json|
        json&.dig("fields", "attachment")&.each do |attachment|
          ids << attachment["id"]
        end
      end
      ids.each { |id| _delete(id) }
    end
  end
end

