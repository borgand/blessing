require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'tmpdir'
require 'fileutils'

describe Blessing::Leader do

  before(:each) do
    @tmpdir = Dir.mktmpdir('blessing_test')
  end

  after(:each) do
    FileUtils.rm_rf @tmpdir
  end

  context "File globbing" do

    it "Takes shell glob pattern and preserves it" do
      pattern = "/tmp/**/*.conf"
      leader = Blessing::Leader.new pattern
      leader.patterns.should == [pattern]
    end

    it "takes multiple patterns" do
      patterns = %w(/tmp/**/1.conf /tmp/**/2.conf)
      leader = Blessing::Leader.new patterns
      leader.patterns.should == patterns
    end

  end

  context "Renew config files" do

    it "finds a list of files corresponding to the pattern" do
      files = []
      3.times do |i|
        files << name = File.join(@tmpdir,"unicorn_#{i}.conf")
        FileUtils.touch name
      end
      leader = Blessing::Leader.new("#{@tmpdir}/**/unicorn_*.conf")
      leader.refresh_file_list
      leader.config_files.should == files.sort
    end

    it "finds a unique list of files corresponding to multiple patterns" do
      files = []
      3.times do |i|
        files << name = File.join(@tmpdir,"unicorn_#{i}.conf")
        FileUtils.touch name
      end
      leader = Blessing::Leader.new(%W(#{@tmpdir}/**/unicorn_1.conf #{@tmpdir}/**/unicorn_*.conf))
      leader.refresh_file_list
      leader.config_files.should == files.sort
    end


    it "refreshes file list and preserves old list" do
      old_files = []
      3.times do |i|
        old_files << name = File.join(@tmpdir,"unicorn_#{i}.conf")
        FileUtils.touch name
      end
      leader = Blessing::Leader.new("#{@tmpdir}/**/unicorn_*.conf")
      leader.refresh_file_list

      # Remove one file and add one file
      new_files = old_files.dup
      File.unlink(new_files.delete_at(1))
      new_files << name = File.join(@tmpdir,"unicorn_4.conf")
      FileUtils.touch name

      leader.refresh_file_list

      # Leader#old_config_files is private
      leader.old_config_files.should == old_files
      leader.config_files.should == new_files
    end

    it "compares old conf list to the new and starts and stops Runners as neccessary" do
      old_config_files = (1..2).map{|i| File.join(@tmpdir,"unicorn_#{i}.conf")}
      config_files = (2..3).map{|i| File.join(@tmpdir,"unicorn_#{i}.conf")}
      runner_mock = double(Blessing::Runner)

      leader = Blessing::Leader.new "#{@tmpdir}/**/unicorn_*.conf"
      leader.old_config_files = old_config_files
      leader.config_files = config_files

      leader.should_receive(:stop_runners).with([File.join(@tmpdir,"unicorn_1.conf")])
      leader.should_receive(:start_runners).with([File.join(@tmpdir,"unicorn_3.conf")])

      leader.start_stop_runners

    end

    it "does not start/stop any runners if no config files change" do
      conf = "#{@tmpdir}/unicorn_conf"
      mock_runner = double(Blessing::Runner)
      mock_runner.should_not_receive(:start)
      mock_runner.should_not_receive(:stop)

      leader = Blessing::Leader.new ""
      leader.config_files = leader.old_config_files = [conf]
      leader.runners[conf] = mock_runner

      leader.should_receive(:start_runners).with([])
      leader.should_receive(:stop_runners).with([])

      leader.start_stop_runners
    end

  end

  context "Process monitoring" do
    it "starts Runners" do
      mock_runner = double(Blessing::Runner)
      mock_runner.should_receive(:start)
      Blessing::Runner.should_receive(:new).and_return(mock_runner)

      leader = Blessing::Leader.new("")

      leader.start_runners(["#{@tmpdir}/unicorn_conf"])
    end

    it "stops Runners" do
      mock_runner = double(Blessing::Runner)
      mock_runner.should_receive(:stop)
      conf = "#{@tmpdir}/unicorn_conf"

      leader = Blessing::Leader.new("")
      leader.runners[conf] = mock_runner
      
      leader.stop_runners([conf])
      # Stopped runners should be removed from queue
      leader.runners.should == {}
    end

    it "asks Runners to check if reload is necessary" do
      mock_runner = double(Blessing::Runner)
      mock_runner.should_receive(:check_reload)

      leader = Blessing::Leader.new("")
      conf = "#{@tmpdir}/unicorn.conf"
      leader.config_files = [conf]
      leader.runners[conf] = mock_runner

      leader.reload_runners
    end

  end

  context "Main API" do
    it "does refresh-start-stop-reload cycle" do
      leader = Blessing::Leader.new("")
      leader.should_receive(:refresh_file_list)
      leader.should_receive(:start_stop_runners)
      leader.should_receive(:reload_runners)

      leader.run_cycle
    end

    it "when started, runs cycle every X seconds, until stopped" do
      leader = Blessing::Leader.new "", :refresh => 1
      count = 1
      leader.stub(:run_cycle) do
        leader.stop if count <= 0
        count -= 1
      end
      leader.should_receive(:run_cycle).twice
      leader.start

    end

    it "stops all runners when stopped" do
      leader = Blessing::Leader.new ""
      leader.should_receive(:stop_runners)
      leader.stop
    end

    it "daemonizes when asked" do
      leader = Blessing::Leader.new "", :daemonize => true, :refresh => 0

      Daemons.should_receive(:daemonize)

      count = 1
      leader.stub(:run_cycle) do
        leader.stop if count <= 0
        count -= 1
      end
      leader.should_receive(:run_cycle).twice
      leader.start

    end
  end

  context "Logging" do
    it "creates logger facility" do
      leader = Blessing::Leader.new ""
      leader.logger.should respond_to :debug
      leader.logger.should respond_to :info
      leader.logger.should respond_to :warn
      leader.logger.should respond_to :error
      leader.logger.should respond_to :fatal
    end
  end
end

