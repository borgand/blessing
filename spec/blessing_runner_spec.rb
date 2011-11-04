require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'tmpdir'
require 'fileutils'

describe Blessing::Runner do
  before(:all) do
    @tmpdir = Dir.mktmpdir('blessing_test')
    @conf = make_sample_config(@tmpdir)
  end

  after(:all) do
    FileUtils.rm_rf @tmpdir
  end

  context "Read configuration" do

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
      runner.should_receive(:pid).ordered.and_return(pid)
      Process.should_receive(:kill).ordered.with(0, pid).and_return(true)
      runner.running?.should be_true

      pid = 22345
      runner.should_receive(:pid).ordered.and_return(pid)
      Process.should_receive(:kill).ordered.with(0, pid) { raise Errno::ESRCH, "TestException" }
      runner.running?.should_not be_true
    end
    
    it "assumes not running when PID is missing" do
      runner = Blessing::Runner.new(@conf)
      
      runner.should_receive(:pid).and_return(nil)
      Process.should_not_receive(:kill)
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
      runner.dead?.should be_true
    end

    it "won't touch dead Unicorn" do
      runner = Blessing::Runner.new @conf, :refresh => 0
      runner.should_receive(:dead?).and_return(true)

      runner.check_reload.should_not be_true
    end

    it "resurrects" do
      runner = Blessing::Runner.new @conf, :refresh => 0
      runner.instance_eval("@dead = true")
      runner.should_receive(:ensure_running)
      runner.should_receive(:running?).and_return(true)

      runner.check_reload(true)
      runner.dead?.should be_false
    end

    it "detects that configuration file has been modified" do
      runner = Blessing::Runner.new(@conf)

      runner.config_modified?.should_not be_true
      sleep 1
      FileUtils.touch @conf
      runner.config_modified?.should be_true
    end
  end

  context "main monitoring cycle" do 

    it "reloads if needed and ensures Unicorn is running" do
      runner = Blessing::Runner.new(@conf)
      runner.should_receive(:config_modified?).and_return(true)
      runner.should_receive(:reload)
      runner.should_receive(:ensure_running)

      runner.check_reload
    end

  end

  context "logging" do
    it "connects to leader logger" do
      logger = double
      logger.stub(:debug)
      logger.stub(:notice)
      logger.stub(:info)
      logger.stub(:warn)
      logger.stub(:error)
      logger.stub(:fatal)

      leader = double(Blessing::Leader)
      leader.stub(:logger){logger}


      runner = Blessing::Runner.new(@conf, :leader => leader)
      runner.logger.should respond_to :debug
    end

    it "creates logger if leader not connected" do
      runner = Blessing::Runner.new @conf
      runner.logger.should respond_to :debug
    end
  end
end
