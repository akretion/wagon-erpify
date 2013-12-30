require 'erpify'
require 'locomotive/mounter'
require 'locomotive/wagon/server'
require 'ostruct'
require 'cgi'
require 'delegate'
require 'ooor/rack'


module Erpify
  module ContentEntryHelper
    include Ooor::LocaleMapper

    def content_type
      locale = Locomotive::Mounter.locale.to_s
      context = {'lang' => to_erp_locale(locale)}
      @content_type ||= OpenStruct.new(slug: self.class.param_key(context))
    end

    def content_entry
      self
    end

    def _slug
      to_param
    end

    def _permalink
      to_param
    end

    def _label
      name
    end
  end
end

Ooor::Base.send :include, Erpify::ContentEntryHelper


class SlugDecorator < SimpleDelegator
  def initialize(obj, slug)
    super(obj)
    @delegate_slug = slug
  end

  def slug
    @delegate_slug
  end
end


module Locomotive
  module Mounter
    module Models
      class Page < Base

        def content_type_with_erpify
          c_type = content_type_without_erpify
          if c_type && c_type.slug == 'ooor_entries'
            SlugDecorator.new(c_type, self.to_s.split('/')[0])
          else
            c_type
          end
        end

        alias_method :content_type_without_erpify, :content_type
        alias_method :content_type, :content_type_with_erpify
      end
    end
  end
end


module Locomotive::Wagon
  class Server
    class Page < Middleware # sadly unlike Rails Wagon offers us no way to place our OOOR middleware at the right position, that's why we monkey patch instead

      def call_with_erpify(env)
        ooor_rack = Ooor::Rack.new(@app)
        ooor_rack.set_ooor!(env)
        erpify_assigns = {
                          "ooor_public_model" => Erpify::Liquid::Drops::OoorPublicModel.new(),
                          "ooor_model" => Erpify::Liquid::Drops::OoorPublicModel.new(), #no authentication in Wagon
                        }
        env["wagon.liquid_assigns"].merge!(erpify_assigns)
        call_without_erpify(env)
      end

      alias_method :call_without_erpify, :call
      alias_method :call, :call_with_erpify

      def set_ooor_context!(env)
        
      end
    end


    class TemplatizedPage < Middleware
      def set_content_entry!(env)
        %r(^#{self.page.safe_fullpath.gsub('*', '([^\/]+)')}$) =~ self.path

        permalink = $1

        if page.content_type_without_erpify.slug == 'ooor_entries'
          method_or_key = self.path.split('/')[0].gsub('-', '.')
          lang = env['ooor']['ooor_context']['lang'] || 'en_US'
          model = Ooor::Base.connection_handler.retrieve_connection(Ooor.default_config).const_get(method_or_key, lang)
          env['wagon.content_entry'] = model.find_by_param(CGI::unescape(permalink))
        else
          if content_entry = self.page.content_type.find_entry(permalink)
            env['wagon.content_entry'] = content_entry
          else
            env['wagon.page'] = nil
          end
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
  config_file = "#{Dir.pwd}/config/ooor.yml"
  config = YAML.load_file(config_file)['development']
  Ooor.default_config = HashWithIndifferentAccess.new(config).merge(locale_rack_key: 'wagon.locale')
rescue SystemCallError
  puts """failed to load OOOR yaml configuration file.
       make sure your app has a #{config_file} file correctly set up\n\n"""
end
