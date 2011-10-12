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

    it "verifies that Unicorn process is running" do
      runner = Blessing::Runner.new(@conf)

      pid = 12345
      runner.should_receive(:pid).and_return(pid)
      Process.should_receive(:kill).with(0, pid).and_return(true)
      runner.running?.should be_true

      pid = 22345
      runner.should_receive(:pid).and_return(pid)
      Process.should_receive(:kill).with(0, pid) { raise Errno::ESRCH, "TestException" }
      runner.running?.should_not be_true
    end

    it "restarts stopped Unicorn process" do
      runner = Blessing::Runner.new(@conf)

      runner.opts[:retry_delay] = 0
      runner.should_receive(:running?).exactly(:once).and_return(false)
      runner.should_receive(:running?).once.and_return(true)
      runner.should_receive(:start)

      runner.ensure_running.should be_true
    end

    it "stops trying to restart if too many failures" do
      runner = Blessing::Runner.new(@conf)

      max_tries = 3
      runner.opts[:max_restarts] = max_tries
      runner.opts[:retry_delay] = 0

      runner.should_receive(:running?).exactly(max_tries + 1).times.and_return(false)
      runner.should_receive(:start).exactly(max_tries).times

      runner.ensure_running.should_not be_true
    end

    it "reloads Unicorn if conf file has changed"

    it "checks if reload or restart is necessary"

  end
end
