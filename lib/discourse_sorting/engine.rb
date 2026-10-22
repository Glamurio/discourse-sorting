# frozen_string_literal: true

module ::DiscourseSorting
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseSorting
    config.autoload_paths << File.join(config.root, "lib")
  end
end
