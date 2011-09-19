require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'tmpdir'
require 'fileutils'

describe Blessing::Runner do
  context "Read configuration" do
    before(:all) do
      @tmpdir = Dir.mktmpdir('blessing_test')
      @conf = File.join(@tmpdir,"unicorn.conf")
      make_sample_config(@conf)
    end

    after(:all) do
      FileUtils.rm_rf @tmpdir
    end

    it "takes config file as argument to new" do
      runner = Blessing::Runner.new(@conf)
      runner.config_file.should == @conf
    end



    it "parses conf files for pid file and working_directory location" do
      runner = Blessing::Runner.new(@conf)
      pid = File.join(File.dirname(@conf), "/tmp/pids/unicorn.pid")
      runner.conf[:pid].should == pid
    end

    it "starts Unicorn process"

    it "collects all PIDs"

    it "stops Unicorn process"

    it "reloads Unicorn process"

    it "checks if Unicorn process is running"

    it "starts stopped Unicorn process"

    it "retries Unicorn restart only X times"

    it "reloads Unicorn if conf file has changed"

  end
end
