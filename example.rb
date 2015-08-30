require 'io/console'


# def strand(x:, y:, speed:, radius:)
#   max_y, max_x = $stdout.winsize
#   timeout = 1.0 / speed
#   y.upto max_y do |y_off|
#     coords = max_x.times.map do |i|
#       Math.sin(y_off + i/max_x.to_f).*(radius).to_i
#     end
#     # coords = []
#     # coords = coords.drop(coords.length./(3).to_i).take(coords.length./(3).to_i)
#     coords.each do |x_off|
#       saturation = 6 * x_off.abs / radius
#       print "\e[#{y_off};#{x+x_off}H\e[38;5;#{16+saturation*36}mo"
#     end

#     x_off = Math.sin(y_off).*(radius).to_i
#     saturation = 6 * x_off.abs / radius

#     print "\e[#{y_off};#{x+x_off}H\e[38;5;#{16+saturation*36}mo"
#     sleep timeout
#   end
# end

# strands = Strands.new
colour   = :red

class Console
  attr_accessor :stdin, :stdout, :finished, :enqueued_keys, :callbacks

  alias finished? finished

  def initialize(stdin, stdout)
    self.stdin         = stdin
    self.stdout        = stdout
    self.finished      = false
    self.enqueued_keys = []
    self.callbacks     = {}
  end

  def on(event, &block)
    callbacks[event] = block
    self
  end

  def emit(event, *args)
    callbacks[event] && callbacks[event].call(self, *args)
  end

  def get_key
    if enqueued_keys.any?
      char = enqueued_keys.shift
    else
      char = stdin.getc
    end

    # not an escape
    if char != "\e"
      return case char
             when " "        then [:space]
             when "\r", "\n" then [:return]
             when 3.chr      then [:ctrl_c]
             else [char.intern]
             end
    end

    # not an escape sequence
    char = stdin.getc
    if char != "["
      enqueued_keys << char
      return [:escape]
    end

    # get the escape sequence
    arg_str = ""
    char    = nil
    loop do
      char = stdin.getc
      break if char !~ /[0-9;]/
      arg_str << char
    end
    arguments = arg_str.split(";").map(&:to_i)

    # interpret the escape sequence
    case char
    when "M"
      # space is mouse down, # is mouse up
      direction = :mouse_down
      direction = :mouse_up if stdin.getc == "#"

      # x and y are offset by 32 for some reason
      x = stdin.getc.force_encoding(Encoding::ASCII_8BIT).ord - 32
      y = stdin.getc.force_encoding(Encoding::ASCII_8BIT).ord - 32

      [direction, x, y]
    else
      [:ignored] # no op for now
    end
  end

  def start
    stdin.raw!
    hide_cursor
    clear_screen
    record_mouse true
    emit *get_key until finished?
  ensure
    stdin.cooked!
    goto x: 1, y: 1
    show_cursor
    record_mouse false
  end

  def goto(x:, y:)
    print "\e[#{y};#{x}H"
  end

  def show_cursor
    print "\e[?25h"
  end

  def finish
    self.finished = true
  end

  def hide_cursor
    print "\e[?25l"
  end

  def clear_screen
    print "\e[H\e[2J" # go to top-left and clear to bottom right
  end

  def record_mouse(do_it)
    print(do_it ? "\e[?1000h": "\e[?1000l")
  end

  def print(message)
    stdout.print message
  end
end

Console
  .new($stdin, $stdout)
  .on(:space)      { |console| console.clear_screen }
  .on(:return)     { |console| console.finish       }
  .on(:ctrl_c)     { |console| console.finish       }
  .on(:q)          { |console| console.finish       }
  .on(:r)          { |console| colour = :red        }
  .on(:g)          { |console| colour = :green      }
  .on(:b)          { |console| colour = :blue       }
  .on(:y)          { |console| colour = :yellow     }
  .on(:m)          { |console| colour = :magena     }
  .on(:c)          { |console| colour = :cyan       }
  .on(:mouse_down) { |console, x, y| strands.add x: 20, y: 8, radius: 8, speed: 100 colour: colour }
  .start
