require 'json'
require 'tabry/cli/util'
require 'tabry/shells/bash'
require 'tabry/shells/fish'
require_relative 'config'
require_relative 'builtin_configs'
require_relative 'search_builder'

%w[
  agile attach base changelog create field http issue_actions links list render search
].each do |cli|
  require_relative "#{cli}_cli"
end

module Jir
  class CLI < BaseCLI
    sub_route :agile, to: AgileCLI
    sub_route :assign, :comment, :transition, :web, :watchers,
      to: IssueActionsCLI, full_method_name: true
    sub_route :attach, to: AttachCLI
    sub_route :create, to: CreateCLI
    sub_route :field, to: FieldCLI
    sub_route :get, :search, to: SearchCLI, full_method_name: true
    sub_route :http, to: HttpCLI
    sub_route :links, to: LinksCLI
    sub_route :list, to: ListCLI
    sub_route :render, to: RenderCLI
    sub_route :changelog, to: ChangelogCLI

    def install_builtin_config
      BuiltinConfigs.install args.config_name
    end
  end
end

