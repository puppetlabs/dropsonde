module Puppet
  class Module

    unless Module.method_defined? :"forge_module?"
      def forge_module?
        Dropsonde::Cache.forgeModule? self
      end
    end

    unless Module.method_defined? :forge_slug
      def forge_slug
        self.forge_name.tr('/','-') rescue nil
      end
    end

  end
end
