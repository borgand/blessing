require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'tmpdir'
require 'fileutils'

describe Blessing::Runner do
  context "Read configuration" do
    before(:all) do
      @tmpdir = Dir.mktmpdir('blessing_test')
      @conf = make_sample_config(@tmpdir)
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
      runner.opts[:pid].should == pid
    end

    it "starts and stops Unicorn process" do
      runner = Blessing::Runner.new(@conf)
      runner.start
      runner.opts[:pid].should contain_a_pid_number
      runner.opts[:pid].should point_to_running_process

      runner.stop
      # give it time to die
      sleep 1

      runner.opts[:pid].should_not point_to_running_process
      runner.opts[:pid].should_not contain_a_pid_number
    end

    it "reloads Unicorn process" do
      runner = Blessing::Runner.new(@conf)

      runner.should_receive(:pid).and_return(12345)
      Process.should_receive(:kill).once
      runner.reload

    end

    it "checks if Unicorn process is running"

    it "starts stopped Unicorn process"

    it "retries Unicorn restart only X times"

    it "reloads Unicorn if conf file has changed"

  end
end
