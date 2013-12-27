require 'erpify'
require 'locomotive/wagon/server'

module Locomotive::Wagon
  class Server

    class Renderer < Middleware

      def locomotive_context_with_erpify(other_assigns = {})
        erpiy_assigns = {"ooor_public_model" => Erpify::Liquid::Drops::OoorPublicModel.new()}
        other_assigns.merge!(erpiy_assigns)
        locomotive_context_without_erpify(erpiy_assigns)
      end

      alias_method :locomotive_context_without_erpify, :locomotive_context
      alias_method :locomotive_context, :locomotive_context_with_erpify

    end
  end
end

begin
  config_file = "#{Dir.pwd}/config/ooor.yml"
  Ooor.default_config = HashWithIndifferentAccess.new(YAML.load_file(config_file)['development'])
rescue SystemCallError
  puts """failed to load OOOR yaml configuration file.
       make sure your app has a #{config_file} file correctly set up
       if not, just copy/paste the default ooor.yml file from the OOOR Gem\n\n"""
end
