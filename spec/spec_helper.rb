module SpecHelper
end

class SpecHelper::Instream
  attr_writer :partial_reads, :content, :width, :height
  def initialize(partial_reads:, width:80, height:40, &on_check)
    self.partial_reads, self.width, self.height, @on_check = partial_reads, width, height, on_check
  end

  def eof?
    @partial_reads.empty?
  end

  def read_partial(n)
    str = @partial_reads.shift
    result, remaining = str[0...n], str[n..-1]
    @partial_reads.unshift remaining if remaining && !remaining.empty?
    result
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
