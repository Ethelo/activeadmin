module ActiveAdmin

  # Namespaces are the basic organizing principle for resources within Active Admin
  #
  # Each resource is registered into a namespace which defines:
  #   * the namespaceing for routing
  #   * the module to namespace controllers
  #   * the menu which gets displayed (other resources in the same namespace)
  #
  # For example:
  #   
  #   ActiveAdmin.register Post, :namespace => :admin
  #
  # Will register the Post model into the "admin" namespace. This will namespace the
  # urls for the resource to "/admin/posts" and will set the controller to
  # Admin::PostsController
  #
  # You can also register to the "root" namespace, which is to say no namespace at all.
  #
  #   ActiveAdmin.register Post, :namespace => false
  #
  # This will register the resource to an instantiated namespace called :root. The 
  # resource will be accessible from "/posts" and the controller will be PostsController.
  #
  class Namespace

    attr_reader :resources, :name, :menu

    def initialize(name)
      @name = name.to_s.underscore.to_sym
      @resources = {}
      @menu = Menu.new
      register_module unless root?
      generate_dashboard_controller
    end

    # Register a resource into this namespace. The preffered method to access this is to 
    # use the global registration ActiveAdmin.register which delegates to the proper 
    # namespace instance.
    def register(resource, options = {}, &block)
      # Init and store the resource


      config = Resource.new(self, resource, options)
      @resources[config.camelized_resource_name] = config

      # Register the resource
      register_resource_controller(config)
      parse_registration_block(config, &block) if block_given?
      register_with_menu(config)
      register_with_admin_notes(config) if config.admin_notes?

      # Ensure that the dashboard is generated
      generate_dashboard_controller
      
      # Return the config
      config
    end

    def root?
      name == :root
    end

    # Returns the name of the module if required. Will be nil if none
    # is required.
    #
    # eg: 
    #   Namespace.new(:admin).module_name # => 'Admin'
    #   Namespace.new(:root).module_name # => nil
    #
    def module_name
      return nil if root?
      @module_name ||= name.to_s.camelize
    end

    # Returns the name of the dashboard controller for this namespace
    def dashboard_controller_name
      [module_name, "DashboardController"].compact.join("::")
    end

    # Unload all the registered resources for this namespace
    def unload!
      unload_resources!
      unload_dashboard!
      unload_menu!
    end

    # The menu gets built by Active Admin once all the resources have been
    # loaded. This method gets called to register each resource with the menu system.
    def load_menu!
      register_dashboard
      resources.values.each do |config|
        register_with_menu(config) if config.include_in_menu?
      end
    end

    protected

    def unload_resources!
      resources.each do |name, config|
        parent = (module_name || 'Object').constantize
        const_name = config.controller_name.split('::').last
        # Remove the const if its been defined
        parent.send(:remove_const, const_name) if parent.const_defined?(const_name)
      end
    end

    def unload_dashboard!
      # TODO: Only clear out my sections
      Dashboards.clear_all_sections!
    end

    def unload_menu!
      @menu = Menu.new
    end

    # Creates a ruby module to namespace all the classes in if required
    def register_module
      eval "module ::#{module_name}; end"
    end

    def register_resource_controller(config)
      eval "class ::#{config.controller_name} < ActiveAdmin::ResourceController; end"
      config.controller.active_admin_config = config
    end

    def dsl
      @dsl ||= DSL.new
    end

    def parse_registration_block(config, &block)
      dsl.run_registration_block(config, &block)
    end

    # Creates a dashboard controller for this config
    def generate_dashboard_controller
      eval "class ::#{dashboard_controller_name} < ActiveAdmin::Dashboards::DashboardController; end"
    end

    # Adds the dashboard to the menu
    def register_dashboard
      dashboard_path = root? ? :dashboard_path : "#{name}_dashboard_path".to_sym
      menu.add("Dashboard", dashboard_path, 1) unless menu["Dashboard"]
    end

    # Does all the work of registernig a config with the menu system
    def register_with_menu(config)
      # The menu we're going to add this resource to
      add_to = menu

      # Adding as a child
      if config.parent_menu_item_name
        # Create the parent if it doesn't exist
        menu.add(config.parent_menu_item_name, '#') unless menu[config.parent_menu_item_name]
        add_to = menu[config.parent_menu_item_name]
      end

      # Check if this menu item has already been created
      if add_to[config.menu_item_name]
        # Update the url if it's already been created
        add_to[config.menu_item_name].url = config.route_collection_path
      else
        add_to.add(config.menu_item_name, config.route_collection_path)
      end
    end
    
    def register_with_admin_notes(config)
      config.resource.has_many :admin_notes, :as => :resource, :class_name => "ActiveAdmin::AdminNote"
    end
  end
end
