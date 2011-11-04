# Validate that the file contains numeric pid
RSpec::Matchers.define :contain_a_pid_number do
  match do |actual|
    if File.exists? actual
      @pid = File.read(actual).chomp
      @pid.to_i.to_s == @pid.chomp
    else
      false
    end
  end
  
  failure_message_for_should do |actual|
    "File #{actual} expected to contain PID number instead of: #{@pid.inspect}"
  end
  
  failure_message_for_should_not do |actual|
    "File #{actual} expected not to contain PID number: #{@pid.inspect}"
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
