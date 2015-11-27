require 'terminal_whisperer/winsize'

class WsAssert
  def initialize(width:,height:)
    @num_times_checked = 0
    @instream = Instream.new width: width, height: height do
      @num_times_checked += 1
    end

    @fake_trap = FakeTrap.new
    @winsize = TerminalWhisperer::Winsize.new(
      instream: @instream,
      trap:     @fake_trap.method(:trap),
      kill:     @fake_trap.method(:kill),
    )
  end

  def has_size!(width:, height:)
    expect(@winsize.width).to  eq width
    expect(@winsize.height).to eq height
  end

  def change_size(width:, height:)
    @instream.width  = width
    @instream.height = height
  end

  def times_checked!(n)
    expect(@num_times_checked).to eq n
  end

  def send_signal(signal_name)
    @fake_trap.kill signal_name, Process.pid
  end

  def default_trap_called!(signal_name, times:)
    expect(@fake_trap.times_default_called(signal_name)).to eq times
  end

  private

  include RSpec::Matchers

  class Instream
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

  class FakeTrap
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
end

RSpec.describe 'Winsize' do
  let(:width)   { 100 }
  let(:width2)  { 101 }
  let(:height)  { 200 }
  let(:height2) { 202 }

  it 'knows the width values of the current window' do
    ws = WsAssert.new width: width, height: height
    ws.has_size!      width: width, height: height
  end

  it 'does not recheck width and height every time it is asked' do
    ws = WsAssert.new width: width,  height: height
    ws.has_size!      width: width,  height: height
    ws.change_size    width: width2, height: height2
    ws.has_size!      width: width,  height: height
    ws.times_checked! 1
  end

  it 'does recheck width and height when it receives a WINCH signal' do
    ws = WsAssert.new width: width,  height: height
    ws.has_size!      width: width,  height: height
    ws.change_size    width: width2, height: height2
    ws.times_checked! 1
    ws.send_signal "WINCH"
    ws.has_size!      width: width2, height: height2
    ws.times_checked! 2
  end

  it 'calls the previously registered callback when it receives a WINCH signal' do
    ws = WsAssert.new width: width, height: height
    ws.default_trap_called! 'WINCH', times: 0
    ws.send_signal "WINCH"
    ws.default_trap_called! 'WINCH', times: 1
  end
end
