module Jir
  class HttpCLI < BaseCLI
    def main; http_action(:get); end
    def get; http_action(:get); end
    def post; http_action(:post); end
    def put; http_action(:put); end

    private
    def http_action(method)
      extra = "%s " * args.args.count
      jira(args.url, extra, args.args, no_api: flags.no_api, api_version_3: flags.api_version_3, api_agile: flags.agile, method: method)
    end
  end
end
