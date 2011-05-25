require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'settings_tree'

describe "SettingsTree" do
	
	before(:all) do
		#puts "Reseting settings before the suite..."
		SettingsHolder.instance.reset
	end
	
	it "should be able to load settings from a file" do
		res = Settings.register_settings_file('web_app', File.join(File.dirname(__FILE__), "test_files/config.yml"))
		res.should be_true
	end
	
	it "should provide a convenient way to access settings" do
		Settings.web_app.root_url.should == 'localhost:3000'
		Settings.web_app.public_access.should be_true
		
		Settings.web_app.infos.company_name.should == 'Acme'
		Settings.web_app.infos.app_name.should == 'Coffe maker'
		Settings.web_app.infos.copyright_starting_year.should == 2011
		Settings.web_app.infos.legend.should == 'A superb app which does ...'
		
		Settings.web_app.engine.workers_count.should == 3
		Settings.web_app.engine.auto_manage_workers.should == true
		Settings.web_app.engine.auto_manage_workers_redirect_output.should == true
		
		# now we'll query non-existent fields just to be sure
		Settings.web_app.infos.foo.should be_nil
	end
	
	it "should be able to load settings from two files at once" do
		res = Settings.register_settings_file('web_app', File.join(File.dirname(__FILE__), "test_files/config_complement.yml"))
		res.should be_true
		
		# now let's query the new/changed values
		Settings.web_app.root_url.should == 'talkmap.testhost:3000'
		Settings.web_app.engine.workers_count.should == 3 # cause no environment
		Settings.web_app.foo.bar.should == 42
	end
	
	it "should be able to hold several groups of settings" do
		res = Settings.register_settings_file('web_game', File.join(File.dirname(__FILE__), "test_files/another_config.yml"))
		res.should be_true
		
		# now let's query the new values
		Settings.web_game.guild_name.should == 'gang'
		Settings.web_game.party_size.should == 4
	end
	
	it "should provide a way to reload settings" do
		res = Settings.reload_all
	end
	
end
