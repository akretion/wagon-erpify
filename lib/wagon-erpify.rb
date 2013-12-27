require 'erpify'
require 'locomotive/mounter'

module Erpify
  module ContentTypesReader
    def initialize(runner)
      attributes = {"name"=>"Ooor Entry", "slug"=>"ooor_entries", "description"=>"Ooor Entry", "label_field_name"=>"name", "fields"=>[]}
      res = super(runner)
      add(attributes)
      res
    end
  end
end

Locomotive::Mounter::Reader::FileSystem::ContentTypesReader.send :include, Erpify::ContentTypesReader

#FIXME unfortunately, in wagon/lib/locomotive/wagon.rb:169:in `require_mounter'
# the mounter will start loading content from the file system BEFORE we could register this
# Erpify::ContentTypesReader that will ensure the ooor_entries content_entry will be found
# that is content_types are already loaded without it and templatized page using it will
# have no content_type at this point. This is why we have to reload these contents it as a work around:

runner = Locomotive::Mounter::Reader::FileSystem.instance
runner.run!(runner.parameters.merge({path: runner.path}))
#r = Locomotive::Mounter::Reader::FileSystem::ContentTypesReader.new(runner)
#runner.mounting_point.register_resource('content_types', r.read)

#r = Locomotive::Mounter::Reader::FileSystem::PagesReader.new(runner)
#runner.mounting_point.register_resource('pages', r.read)


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


    class TemplatizedPage < Middleware
      def set_content_entry!(env)
        %r(^#{self.page.safe_fullpath.gsub('*', '([^\/]+)')}$) =~ self.path

        permalink = $1

        if page.content_type.slug == 'ooor_entries'
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
            context.scopes.reverse_each do |scope|
              handle = scope[@handle] || @handle
              return handle if handle.is_a?(Ooor::Base)
            end
            retrieve_page_from_handle_without_erpify(context)
          end

          alias_method :retrieve_page_from_handle_without_erpify, :retrieve_page_from_handle
          alias_method :retrieve_page_from_handle, :retrieve_page_from_handle_with_erpify

          def public_page_fullpath_with_erpify(context, page)
            if page.is_a?(Ooor::Base)
              return File.join('/', page.class.openerp_model.gsub('.', '-'), '/', page.id.to_s)
            else
              public_page_fullpath_without_erpify(context, page)
            end
          end

          alias_method :public_page_fullpath_without_erpify, :public_page_fullpath
          alias_method :public_page_fullpath, :public_page_fullpath_with_erpify

        end


        class LinkTo < Hybrid
          def label_from_page(page)
            if page.is_a?(Ooor::Base)
              return page.name
            end

            ::Locomotive::Mounter.with_locale(@_options['locale']) do
              if page.templatized?
                page.content_entry._label
              else
                page.title
              end
            end
          end

        end
      end
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
