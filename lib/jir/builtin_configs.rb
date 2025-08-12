require_relative 'config'
require 'fileutils'

module Jir
  module BuiltinConfigs
    module_function
    def names
      Dir["#{builtin_dir}/*.yml"].map { |file| File.basename(file).gsub(/\.yml$/, '') }
    end

    def install(config_name)
      config_name = config_name.gsub('/', '') # don't allow looking in other directories
      full_builtin_path = "#{builtin_dir}/#{config_name}.yml"
      unless File.exist?(full_builtin_path)
        raise "Built-in config file #{full_builtin_path.inspect} does not exist"
      end
      FileUtils.mkdir_p Config.config_dir
      File.symlink full_builtin_path, "#{Config.config_dir}/#{config_name}.yml"
    end

    private_class_method
    def builtin_dir
      File.expand_path("../../configs", __dir__)
    end
  end
end
