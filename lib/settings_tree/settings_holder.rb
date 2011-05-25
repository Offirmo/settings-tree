require 'singleton'
require 'recursive_open_struct'
require 'hash_deep_merge'
require 'yaml'

##
# Part of the "rails-settings" gem, this class is designed
# to store several OpenStruct representing 'settings'.
# It can load them from a YAML file, reload them, and accept queries.
#
# This class is usually not used directly but through the 'settings' module, offering shortcuts.
# ---
#
class SettingsHolder
	
	# We want this class to be a singleton.
	# This is on of the cases where singletons are acceptable.
	include Singleton
	
	### Variables
	@settings_list = nil
	
	@environment = nil
	attr_accessor :environment
	
	### Implementation
	
	# a convenience function which reset the settings,
	# forgetting about all the groups, files, etc.
	def reset
		initialize
	end
	
	# a convenience function which displays the datas
	def debug_inspect
		puts "*** Current settings :"
		#puts @settings_list.inspect
		@settings_list.each do |key, value|
			puts "Settings.#{key}."
			@settings_list[key][:data].debug_inspect(1)
		end
	end
	
	# Register a source file for a group.
	# The group will be created if not already existing.
	def register_settings_file(name, file)
		
		group_just_created = false
		
		# create the group if not already here
		unless has_group?(name)
			register_new_group(name) unless has_group?(name)
			group_just_created = true
		end
		
		# add this file as source
		res = false
		begin
			res = register_new_src_file_for_group(name, file)
		rescue Exception => e
			# delete group if just created ? Not for now.
			# proceed with exception
			raise e
		end
		
		return res
	end
	
	# Return this group of settings as an openstruct
	def get_settings(name)
		#puts name.inspect
		#puts @settings_list.inspect
		if !@settings_list.has_key?(name) then
			raise ArgumentError, "Settings : unknown settings group '#{name.to_s}'"
		else
			return @settings_list[name][:data]
		end
	end
	
	def environment=(env)
		@environment = env
		
		# need to reload all
		reload_all
	end
	
	def reload_all
		@settings_list.each do |key, value|
			reload_group(key)
		end
	end
	
	def reload_group(name)
		
		res = false
		
		if !has_group?(name) then
			raise ArgumentError, "This group doesn't exist !"
		else
			data = Hash.new
			
			@settings_list[name.to_sym][:src].each do |src|
				data.deep_merge!(hash_data_for_src(src))
			end
			
			@settings_list[name.to_sym][:data] = RecursiveOpenStruct.new(data)
			res = true
		end # check parameters
		
		return res
	end
	
	protected
		
		def initialize
			@settings_list = Hash.new
			
			if defined? Rails then
				@environment = Rails.env
			end
		end
		
		def has_group?(name)
			#puts @settings_list.inspect
			return @settings_list.has_key?(name.to_sym)
		end
		
		def register_new_group(name)
			
			if has_group?(name) then
				raise ArgumentError, "This group already exists !"
			else
				@settings_list[name.to_sym] = {:data => nil, :src => Array.new }
			end # check parameters
			
			true
		end
		
		def group_has_src?(name, type, value)
			
			if !has_group?(name) then
				raise ArgumentError, "This group doesn't exist !"
			else
				@settings_list[name.to_sym][:src].any? {|src| src[:type] == type && src[:value] == value}
			end # check parameters
		end
		
		def register_new_src_file_for_group(name, file)
			
			res = false
			
			if !has_group?(name) then
				raise ArgumentError, "This group doesn't exist !"
			elsif group_has_src?(name, :file, file) then
				# this source is already registered. Ignore.
				# should signal it ?
				# res stays false, like in 'require'
			else
				@settings_list[name.to_sym][:src] << { :type => :file,  :value => file}
				# don't forget to update to take the new infos into account
				begin
					res = reload_group(name)
				rescue Exception => e
					# remove the src, since it's invalid
					@settings_list[name.to_sym][:src].each_with_index do |item, index|
						if item[:type] == :file && item[:value] == file then
							@settings_list[name.to_sym][:src].delete_at(index)
							break
						end
					end
					# proceed with exception
					raise e
				end
			end # check parameters
			
			return res
		end
		
		def hash_data_for_src(src)
			data = nil
			
			case src[:type]
			when :file
				begin
					   complete_config = YAML.load_file( src[:value] ) || {}
					    default_config = complete_config['defaults'] || {}
					specialized_config = @environment.nil? ? {} : (complete_config[@environment] || {})
					
					data = default_config.deep_merge(specialized_config)
				rescue Errno::ENOENT => e
					# no file, classic error.
					# resend
					raise e
				rescue Exception => e
					#puts e.inspect
					raise RuntimeError, "XXX There was a problem in parsing the file #{src[:value]}. Please investigate... #{e.message}"
				end
			else  
				raise RuntimeError, "Unknown source type : #{src[:type]}"
			end
			
			return data
		end
		
		
end
