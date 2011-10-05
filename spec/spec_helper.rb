$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'blessing'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|

  # Create sampel configuration with minimal Rack app
  def make_sample_config basedir
    config = File.join(basedir, "unicorn.conf")
    rackup = File.join(basedir, "config.ru")

    FileUtils.mkdir_p File.join(basedir, 'tmp', 'pids')

    File.open config, "w" do |f|
      f.puts <<EOF
worker_processes 4
working_directory "#{basedir}"
listen '#{basedir}/tmp/unicorn.sock', :backlog => 512
timeout 30
pid "#{basedir}/tmp/pids/unicorn.pid"

preload_app true
  if GC.respond_to?(:copy_on_write_friendly=)
  GC.copy_on_write_friendly = true
end
EOF
    end

    File.open rackup, "w" do |f|
      f.puts <<EOF
ip = lambda do |env|
  [200, {"Content-Type" => "text/plain"}, [env["REMOTE_ADDR"]]]
end
   
run ip
EOF
    end

    return config
  end
end
