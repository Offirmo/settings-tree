require 'settings_tree/settings_holder'

module Settings
	
	### Convenient shortcuts to the SettingsHolder class
	def self.register_settings_file(name, file)
		SettingsHolder.instance.register_settings_file(name, file)
	end
	def self.reload_all
		return SettingsHolder.instance.reload_all
	end
	def self.reload_group(name)
		return SettingsHolder.instance.reload_group(name)
	end
	
	# automatic access to settings groups
	def self.method_missing(method, *args, &block)
		return SettingsHolder.instance.get_settings(method)
	end
	
end
