require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'settings_tree/settings_holder'

#
#  XXX   WARNING   XXX
# Due to the singleton nature of the class tested
# It is *NOT* reset between individual tests.
# Keep it in mind.
#

describe "SettingsHolder" do
	
	before(:all) do
		#puts "Reseting settings before the suite..."
		SettingsHolder.instance.reset
	end
	
	describe "basic use" do
		
		it "should be instantiable" do
			s = SettingsHolder.instance
			s.should_not be_nil
		end
		
		it "should be able to load settings from a file" do
			res = SettingsHolder.instance.register_settings_file(:web_app, File.join(File.dirname(__FILE__), "test_files/config.yml"))
			res.should be_true
		end
		
		it "should load all settings" do
			# and now let's query all the expected settings
			SettingsHolder.instance.get_settings(:web_app).root_url.should == 'localhost:3000'
			SettingsHolder.instance.get_settings(:web_app).public_access.should be_true
			
			SettingsHolder.instance.get_settings(:web_app).infos.company_name.should == 'Acme'
			SettingsHolder.instance.get_settings(:web_app).infos.app_name.should == 'Coffe maker'
			SettingsHolder.instance.get_settings(:web_app).infos.copyright_starting_year.should == 2011
			SettingsHolder.instance.get_settings(:web_app).infos.legend.should == 'A superb app which does ...'
			
			SettingsHolder.instance.get_settings(:web_app).engine.workers_count.should == 3
			SettingsHolder.instance.get_settings(:web_app).engine.auto_manage_workers.should == true
			SettingsHolder.instance.get_settings(:web_app).engine.auto_manage_workers_redirect_output.should == true
			
			# now we'll query non-existent fields just to be sure
			SettingsHolder.instance.get_settings(:web_app).infos.foo.should be_nil
		end
		
		it "should load and merge specialized settings" do
			
			# Since those tests are not run from a rails app, there is no environment.
			# We'll set one manually.
			
			# before
			SettingsHolder.instance.environment.should be_nil
			SettingsHolder.instance.get_settings(:web_app).engine.auto_manage_workers_redirect_output.should == true
			# change environment (settings are automatically reloaded)
			SettingsHolder.instance.environment = 'development'
			# after
			SettingsHolder.instance.environment.should == 'development'
			SettingsHolder.instance.get_settings(:web_app).engine.auto_manage_workers_redirect_output.should == false
			
			# OK, another one
			# before
			SettingsHolder.instance.environment.should == 'development'
			SettingsHolder.instance.get_settings(:web_app).engine.auto_manage_workers_redirect_output.should == false
			SettingsHolder.instance.get_settings(:web_app).engine.workers_count.should == 3
			# change environment (settings are automatically reloaded)
			SettingsHolder.instance.environment = 'test'
			# after
			SettingsHolder.instance.environment.should == 'test'
			SettingsHolder.instance.get_settings(:web_app).engine.auto_manage_workers_redirect_output.should == true
			SettingsHolder.instance.get_settings(:web_app).engine.workers_count.should == 0
		end
		
		it "should be able to load settings from two files at once" do
			res = SettingsHolder.instance.register_settings_file(:web_app, File.join(File.dirname(__FILE__), "test_files/config_complement.yml"))
			res.should be_true
			
			# now let's query the new/changed values
			SettingsHolder.instance.get_settings(:web_app).root_url.should == 'talkmap.testhost:3000'
			SettingsHolder.instance.get_settings(:web_app).engine.workers_count.should == 27
			SettingsHolder.instance.get_settings(:web_app).foo.bar.should == 42
		end
		
	end
	
	describe "advanced use" do
		it "should handle if a file is invalid" do
			
			# default case : an exception is thrown
			expect {
				SettingsHolder.instance.register_settings_file(:web_app, File.join(File.dirname(__FILE__), "test_files/a_non_existing_file.yml"))
			}.to raise_error(Errno::ENOENT)
			
			# the file shouldn't have been registered, so an update shouldn't throw an exception
			expect {
				SettingsHolder.instance.reload_all
			}.to_not raise_error
			
			# now we have a special option to allow a file to not exist (yet)
			# XXX TODO maybe some day
		end
		
		it "should act correctly if a file is already used" do
			res = SettingsHolder.instance.register_settings_file(:web_app, File.join(File.dirname(__FILE__), "test_files/config.yml"))
			res.should be_false # like in require
		end
		
		it "should be a singleton" do
			expect {
				SettingsHolder.new
			}.to raise_error(NoMethodError)
			
			SettingsHolder.should respond_to :instance
			
			s = SettingsHolder.instance
			SettingsHolder.instance.should == s
		end
		
	end
	
end
