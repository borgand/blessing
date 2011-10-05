# Validate that the file contains numeric pid
RSpec::Matchers.define :contain_a_pid_number do
  match do |actual|
    if File.exists? actual
      pid = File.read(actual).chomp
      pid.to_i.to_s == pid.chomp
    else
      false
    end
  end
end

# Check that the pid is still running
RSpec::Matchers.define :point_to_running_process do
  match do |actual|
    begin
      pid = File.read(actual).chomp.to_i
      res = Process.kill 0, pid
      true
    rescue
      false
    end
  end
end
