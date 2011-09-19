$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'blessing'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|

  def make_sample_config path
    File.open path, "w" do |f|
      basedir = File.dirname path
      basename = File.basename path
      base = basename.sub(/\..*?$/,'')

      f.puts <<EOF
worker_processes 4
working_directory "#{basedir}"
listen '#{basedir}/tmp/#{base}.sock', :backlog => 512
timeout 30
pid "#{basedir}/tmp/pids/unicorn.pid"

preload_app true
  if GC.respond_to?(:copy_on_write_friendly=)
  GC.copy_on_write_friendly = true
end
EOF
    end
  end
end
