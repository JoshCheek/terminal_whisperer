require 'terminal_whisperer/keyboard'

module TerminalWhisperer
  class Key
    def self.from(attrs)
      return attrs if attrs.kind_of? self
      new attrs
    end

    attr_reader :printable
    def initialize(printable:)
      @printable = printable
    end
  end

  class Keymap
    def self.build_keymap_from(keypairs)
      return keypairs if keypairs.kind_of? self
      keymap = new
      keypairs.each { |chars, key_attrs| keymap.add chars, key_attrs }
      keymap
    end

    def find(chars)
      _find chars, 0
    end

    def add(chars, key_attrs)
      _add chars, key_attrs, 0
    end

    protected
    attr_accessor :key

    def _find(chars, depth)
      char = chars[depth]
      if chars.length <= depth
        [key, depth]
      else
        child_key, child_depth = child_keymap_for(char)._find(chars, depth+1)
        if !child_key
          [key, depth]
        else
          [child_key, child_depth]
        end
      end
    end

    def _add(chars, key_attrs, depth)
      if chars.length <= depth
        self.key = Key.from(key_attrs)
      else
        child_keymap_for(chars[depth])._add chars, key_attrs, depth+1
      end
    end

    def child_keymap_for(char)
      (@children||={}).fetch(char) { @children[char] = self.class.new }
    end
  end

  Keymap::DEFAULT = Keymap.build_keymap_from([
    ["z",   {printable: "z"}],
    ["o",   {printable: "o"}],
    ["m",   {printable: "m"}],
    ["g",   {printable: "g"}],
  ])

  class Keyboard
    def initialize(instream:, keymap:)
      self.instream, self.keymap = instream, keymap
      @unprocessed_chunks = []
    end

    include Enumerable
    def each
      return to_enum :each unless block_given?
      until instream.eof?
        @unprocessed_chunks << instream.read_partial(1000)
        while @unprocessed_chunks.any?
          key = process_chunk
          yield key if key
        end
      end
    end

    private

    attr_accessor :instream, :keymap

    def process_chunk
      chunk = key = length = nil
      loop do
        break if @unprocessed_chunks.empty?
        chunk = @unprocessed_chunks.shift
        key, length = keymap.find(chunk)
        break if key
        chunk = chunk[1..-1]
        @unprocessed_chunks.unshift chunk unless chunk.empty?
      end
      @unprocessed_chunks.unshift chunk[length..-1] if length < chunk.length
      key
    end
  end
end

RSpec.describe 'Keyboard' do
  let(:default_keymap) { TerminalWhisperer::Keymap::DEFAULT }

  def build_keymap(keypairs)
    TerminalWhisperer::Keymap.build_keymap_from(keypairs)
  end

  def assert_keyboard(keymap: default_keymap, reads: [], finds: nil)
    instream = SpecHelper::Instream.new partial_reads: reads
    kbd      = TerminalWhisperer::Keyboard.new instream: instream, keymap: build_keymap(keymap)
    expect(kbd.map &:printable).to eq finds if finds
    kbd
  end

  it 'reads each keypress from the input stream' do
    assert_keyboard reads: %w[z o m g], finds: %w[z o m g]
  end

  it 'is enumerable, reading the input stream and emitting Keys' do
    kbd1 = assert_keyboard reads: %w[z o m g]
    kbd2 = assert_keyboard reads: %w[z o m g]
    expect(kbd1.map      &:printable).to eq %w[z o m g]
    expect(kbd2.each.map &:printable).to eq %w[z o m g]
  end

  xit 'does not lock up the thread, even when there is no input'
  xit 'continues querying when there is input to prevent it from aggregating in the pipe and losing the grouping information'

  it 'accepts a keymap telling it how to map chunks of input characters to keys' do
    assert_keyboard reads:  %w[a x aa abd ab abc],
                    finds:  %w[1 6 2 5 3 4],
                    keymap: [ ["a",   {printable: "1"}],
                              ["aa",  {printable: "2"}],
                              ["ab",  {printable: "3"}],
                              ["abc", {printable: "4"}],
                              ["abd", {printable: "5"}],
                              ["x",   {printable: "6"}],
                            ]
  end

  it 'does not consider the chunks contiguous' do
    keymap = build_keymap([
      ["a",   {printable: "1"}],
      ["b",   {printable: "2"}],
      ["ab",  {printable: "3"}],
    ])
    instream = SpecHelper::Instream.new partial_reads: %w[a b]
    kbd      = TerminalWhisperer::Keyboard.new(instream: instream, keymap: keymap)
    expect(kbd.map &:printable).to eq %w[1 2]
  end

  it 'breaks the chunk down into smaller chunks if it cannot match the whole chunk' do
    keymap = build_keymap([
      ["a",   {printable: "1"}],
      ["b",   {printable: "2"}],
    ])
    instream = SpecHelper::Instream.new partial_reads: %w[ab]
    kbd      = TerminalWhisperer::Keyboard.new(instream: instream, keymap: keymap)
    expect(kbd.map &:printable).to eq %w[1 2]
  end

  it 'ignores characters it cannot map' do
    keymap = build_keymap([
      ["q",   {printable: "1"}],
    ])
    instream = SpecHelper::Instream.new partial_reads: %w[q b q]
    kbd      = TerminalWhisperer::Keyboard.new(instream: instream, keymap: keymap)
    expect(kbd.map &:printable).to eq %w[1 1]
  end

  describe 'the default keymap' do
    it 'has keys for each of a-z, A-Z, 0-9, ...'
    it 'has keys for up arrow, down arrow, ...'
  end
end
