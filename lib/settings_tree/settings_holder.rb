require 'singleton'
require 'recursive_open_struct'
require 'hash_deep_merge'
require 'yaml'

##
# Part of the "rails-settings" gem, this class is designed
# to store several OpenStruct representing 'settings'.
# It can load them from a YAML file, reload them, and accept queries.
# ---
#
# Additional functions :
# - auto-normalization of graphs
# - always keep existing coordinates when starting a layout
# - ability to do partial layouts
# - Layout with non-uniform vertices (NUV)
#   NOTE : at the present time, NUV functionality is crude. Vertices are considered circles, with :nuv_parm1 as radius.
# - debug features
# - SVG output
#
# *_WARNING_* every time an attribute is modified directly, the function +report_direct_modifications+
# must be called to tell talkgraph that its internal representation must be updated !
# 
# Note : All attributes are *optional*, talkgraph will figure out default values if not set.
#
# - Attributes are separated between "graph", "vertex" and "edge" according to the corresponding element.
# [param]     parameter = input value : talkgraph will read this value and act accordingly
# [result]    output value : talkgraph will set this value for the user to read.
# [internal]  those attributes are automatically set by the Ruby layer to communicate with the C layer. Do not use or interfere.
#
# Here is the list of attributes which make sense for talkgraph. (any other attribute will be ignored)
# This list MUST be kept coherent with the talkgraph.h declaration.
#
# (Last update : 2011/04/11 by YEJ)
# - graph attributes
#   - Input (parameters)
#     [+:layout+]   the requested layout method. (see possible values below)
#     [+:alea_seed+]   a seed to use when using alea. It helps when we want reproductibility. (not implemented)
#     [+:pautonorm+]   the requested normalization options. (see possible values below)
#     [+:verbose+]   the talkgraph processing will output explanations about what is done
#     [+:fr_niter+, +:fr_maxdelta+, +:fr_area+, +:fr_coolexp+, +:fr_repulserad+, +:fr_cellsize+]   parameters for a Fructhterman-Reingold layout. See igraph documentation.
#     [+:kk_niter+, +:kk_sigma+, +:kk_initemp+, +:kk_coolexp+, +:kk_kkconst+]   parameters for a Kamada-Kawai layout. See igraph documentation.
#   - Output (results)
#     [+:last_layt+] : the last layout method used on this graph. (see possible values below)
#     [+:layt_zoom+] : the zoom applied to the coordinates after the last layout to normalize them
#   - Internal (do not write or delete)
#     - (none)
# - vertices attributes :
#   - Input (parameters)
#     [+:fixed+]   means that this vertex should not move from its current position when computing a layout. (More complicated than that actually.)
#     - Auto-normalization : <b><em>Do not use those attributes directly</em></b> use function xxx_TODO() instead.
#       [+:nrm_centr+]   this vertex should be considered the "center" of this graph for auto-centering normalization.
#       [+:nrmrotref+]   this vertex should be considered the reference for auto-rotation normalization.
#     - Non uniform vertex declaration (NUV) : <b><em>Work in progress !</em></b> <b><em>Do not use those attributes directly</em></b> use function set_vertex_shape() instead.
#       [+:nuv_shape+]   shape of this vertex. For example, rectangle or ellipse. (See possible values below.)
#       [+:nuv_parm1+]   1st parameter of the NUV declaration : May be the width (if rectangle) or the first radius (if ellipse/circle).
#       [+:nuv_parm2+]   2nd parameter of the NUV declaration : May be the height (if rectangle) or the second radius (if ellipse).
#   - Output (results)
#     [+:xpos+, +:ypos+]   see IGraph
#   - Internal (do not write or delete)
#     [+:foreign_id+]   see IGraph
# - edges attributes :
#   - Input (parameters)
#     [+:fr_weight+]   a weight information, only used by Fruchterman-Reingold layout.
#   - Internal (do not write or delete)
#     [+:foreign_id+]   see IGraph
#
# ==== Examples
# -> see also Graph.rb and IGraph.rb examples.
#
# Talkgraph basic use :
#  graph = TalkGraph.new() # create an empty graph object with talkgraph functionalities.
#  graph.add_vertex_with_id(18)   # add a new vertex with ID 18
#  graph.add_vertex_with_id(19)   # ...
#  graph.add_vertex_with_id(20)   # ...
#  graph.add_edge_with_id(15, 19, 18)   # add a new adge with ID 15, between 19 and 18
#  graph.add_edge_with_id(16, 20, 18)   # add a new adge with ID 16, between 20 and 18
#
# Debug :
#  graph.dump_internal_infos      # => displays lot of things
#  graph.to_svg("graph_128.svg")  # => create a corresponding SVG file
#
# layout :
#  graph.vertices    # => { 18 => {}, 19 => {}, 20 => {} }
#  graph.layout
#  graph.vertices    # => { 18 => {:xpos => ..., :ypos => ...}, 19 => {:xpos => ..., :ypos => ...}, 20 => {:xpos => ..., :ypos => ...} }
#
# partial layout :
#  # "fix" the existing nodes
#  graph.vertices[18][:fixed = true]
#  graph.vertices[19][:fixed = true]
#  graph.vertices[20][:fixed = true]
#   # add a new node
#  graph.add_vertex_with_id(21)
#  graph.add_edge_with_id(17, 21, 20)
#  # and layout...
#  graph.report_direct_modifications # XXX very important or else previous modifications will be missed by talkgraph
#  graph.layout
#
# custom layout :
#  graph.attributes[:layout] = TALKGRAPH_LAYOUT_METHOD_KAMADA_KAWAI
#  graph.attributes[:kk_niter] = 3000 # Set Kamada-Kaway parameter "number of iterations" to 3000
#  graph.report_direct_modifications
#  graph.layout
#
# layout with NUV : (in progress, API may change)
#  graph.set_vertex_shape(18, :disc, 10) # node 18 is a disc of radius 10
#  graph.layout
#
# And at the end :
#  graph.free_internal_representation_if_present # very important to avoid memory leaks
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
	
	#
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
