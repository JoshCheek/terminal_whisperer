require 'io/console'

module TerminalWhisperer
  # Example use:
  #   ws = TerminalWhisperer::Winsize.new(
  #     instream: $stdin,
  #     trap:     Kernel.method(:trap),
  #     kill:     Process.method(:kill),
  #   )
  #   10.times do
  #     p width: ws.width, height: ws.height
  #     sleep 1
  #   end
  class Winsize
    def initialize(instream:, trap:, kill:)
      self.instream      = instream
      self.register_trap = trap
      self.their_trap    = register_trap.call 'WINCH', our_trap
      self.invoke_trap   = kill
    end

    def width
      get_size :width
    end

    def height
      get_size :height
    end

    private

    attr_accessor :instream, :register_trap, :their_trap, :invoke_trap

    def get_size(which)
      @sizes ||= Hash[[:height, :width].zip(instream.winsize)]
      @sizes.fetch which
    end

    def our_trap
      -> signalno {
        @sizes = nil
        register_trap.call('WINCH', their_trap)
        invoke_trap.call 'WINCH', Process.pid
        register_trap.call('WINCH', our_trap)
      }
    end
  end
end
