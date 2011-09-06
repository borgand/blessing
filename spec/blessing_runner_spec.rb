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

    it "parses all conf files for pids" do
      pending "Get Unicorn conf parser working"
      leader = Blessing::Leader.new(@conf)
      pids = ["#{@conf.sub(/\..*?$/,'')}.pid"]
      leader.pids.should == pids
    end


  end
end
