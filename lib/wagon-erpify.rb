require 'erpify'
require 'locomotive/mounter'
require 'locomotive/wagon/server'
require 'ostruct'

module Ooor
  class Base #TODO put in a helper
    def content_type
      @content_type ||= OpenStruct.new(slug: 'ooor_entries')
    end

    def content_entry
      self
    end

    def _slug
      id.to_s
    end

    def _label
      name
    end
  end
end


module Locomotive::Wagon
  class Server

    class Renderer < Middleware

      def locomotive_context_with_erpify(other_assigns = {})
        erpiy_assigns = {
                          "ooor_public_model" => Erpify::Liquid::Drops::OoorPublicModel.new(),
                          "ooor_model" => Erpify::Liquid::Drops::OoorPublicModel.new(), #no authentication in Wagon
                        }

        other_assigns.merge!(erpiy_assigns)
        locomotive_context_without_erpify(erpiy_assigns)
      end

      alias_method :locomotive_context_without_erpify, :locomotive_context
      alias_method :locomotive_context, :locomotive_context_with_erpify

    end


    class TemplatizedPage < Middleware
      def set_content_entry!(env)
        %r(^#{self.page.safe_fullpath.gsub('*', '([^\/]+)')}$) =~ self.path

        permalink = $1

        if page.content_type.slug == 'ooor_entries' #TODO match the model or moel alias too
          method_or_key = self.path.split('/')[0].gsub('-', '.')
          model = Ooor::Base.connection_handler.retrieve_connection(Ooor.default_config).const_get(method_or_key)
          env['wagon.content_entry'] = model.find(permalink) #TODO implement find by permalink (and to_param)
          return
        end

        if content_entry = self.page.content_type.find_entry(permalink)
          env['wagon.content_entry'] = content_entry
        else
          env['wagon.page'] = nil
        end
      end
    end



  end
end


module Locomotive
  module Wagon
    module Liquid
      module Tags
        module PathHelper
          def retrieve_page_from_handle_with_erpify(context)
            mounting_point = context.registers[:mounting_point]
            context.scopes.reverse_each do |scope|
              handle = scope[@handle] || @handle
              if handle.is_a?(Ooor::Base)
                return fetch_page(mounting_point, handle, true)
              end
            end
            retrieve_page_from_handle_without_erpify(context)
          end

          alias_method :retrieve_page_from_handle_without_erpify, :retrieve_page_from_handle
          alias_method :retrieve_page_from_handle, :retrieve_page_from_handle_with_erpify

        end
      end
    end
  end
end


begin
  config_file = "#{Dir.pwd}/data/ooor_entries.yml"
  connection_configs = YAML.load_file(config_file)
  config = HashWithIndifferentAccess.new(connection_configs[0])
  Ooor.default_config = HashWithIndifferentAccess.new(config[config.keys[0]]) #FIXME should be first public
rescue SystemCallError
  puts """failed to load OOOR yaml configuration file.
       make sure your app has a #{config_file} file correctly set up\n\n"""
end
