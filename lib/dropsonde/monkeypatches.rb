module Puppet
  class Module
    def forge_module?
      Dropsonde::Cache.forgeModule? self
    end

    def forge_slug
      self.forge_name.tr('/','-') rescue nil
    end
  end
end
