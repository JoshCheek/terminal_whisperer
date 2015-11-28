require 'terminal_whisperer/winsize'
require 'spec_helper'

module SpecHelper
  class WsAssert
    include RSpec::Matchers
    def initialize(width:, height:)
      @num_times_checked = 0
      @instream = Instream.new width: width, height: height, partial_reads:[] do
        @num_times_checked += 1
      end

      @fake_trap = FakeTrap.new
      @winsize = TerminalWhisperer::Winsize.new(
        instream: @instream,
        trap:     @fake_trap.method(:trap),
        kill:     @fake_trap.method(:kill),
      )
    end

    def has_size!(width:nil, height:nil)
      expect(@winsize.width).to  eq width  if width
      expect(@winsize.height).to eq height if height
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
  end
end

RSpec.describe 'Winsize' do
  def asserter(*args)
    SpecHelper::WsAssert.new(*args)
  end

  let(:width)   { 100 }
  let(:width2)  { 101 }
  let(:height)  { 200 }
  let(:height2) { 202 }

  it 'knows the width values of the current window' do
    ws = asserter width: width, height: height
    ws.has_size!  width: width, height: height
  end

  it 'does not matter which order it is asked in' do
    ws = asserter width:  width, height: height
    ws.has_size!  width:  width
    ws.has_size!  height: height

    ws = asserter width:  width, height: height
    ws.has_size!  height: height
    ws.has_size!  width:  width
  end

  it 'does not recheck width and height every time it is asked' do
    ws = asserter  width: width,  height: height
    ws.has_size!   width: width,  height: height
    ws.change_size width: width2, height: height2
    ws.has_size!   width: width,  height: height
    ws.times_checked! 1
  end

  it 'does recheck width and height when it receives a WINCH signal' do
    ws = asserter     width: width,  height: height
    ws.has_size!      width: width,  height: height
    ws.change_size    width: width2, height: height2
    ws.times_checked! 1
    ws.send_signal    "WINCH"
    ws.has_size!      width: width2, height: height2
    ws.times_checked! 2
  end

  it 'calls the previously registered callback when it receives a WINCH signal' do
    ws = asserter width: width, height: height
    ws.default_trap_called! 'WINCH', times: 0
    ws.send_signal "WINCH"
    ws.default_trap_called! 'WINCH', times: 1
  end
end
