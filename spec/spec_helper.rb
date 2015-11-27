module SpecHelper
end

class SpecHelper::Instream
  attr_writer :width, :height
  def initialize(width:,height:, &on_check)
    self.width, self.height, @on_check = width, height, on_check
  end

  def winsize
    [@height, @width]
  ensure
    @on_check.call
  end
end

class SpecHelper::FakeTrap
  def initialize
    @callbacks = Hash.new do |_hash, signal_name|
      -> signal_no { @times_default_called[signal_name] += 1 }
    end
    @times_default_called =  Hash.new(0)
  end

  def kill(signal_name, pid)
    if pid == Process.pid
      @callbacks[signal_name].call Signal.list.fetch(signal_name)
    else
      raise "Trying to kill another process! #{pid.inspect} should be #{Process.pid.inspect}"
    end
  end

  def trap(signal_name, callback)
    old_value = @callbacks[signal_name]
    @callbacks[signal_name] = callback
    old_value
  end

  def times_default_called(signal_name)
    @times_default_called[signal_name]
  end
end
