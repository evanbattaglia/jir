require_relative 'base_cli'

module Jir
  class AttachCLI < BaseCLI
    def main
      jira(
        "issue/#{ticket_key}/attachments",
        "%s file@%s",
        [
          "X-Atlassian-Token: nocheck",
          args.filename
        ],
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
  end
end

