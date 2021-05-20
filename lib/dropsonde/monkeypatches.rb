# frozen_string_literal: true

# puppet module class
class Puppet::Module
  unless Module.method_defined? :"forge_module?"
    def forge_module?
      Dropsonde::Cache.forge_module? self
    end
  end

  unless Module.method_defined? :forge_slug
    def forge_slug
      forge_name.tr('/', '-')
    rescue StandardError
      nil
    end
  end
end
