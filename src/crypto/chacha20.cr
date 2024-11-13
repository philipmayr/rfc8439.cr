# The ChaCha20 cipher is a high-speed cipher.
# It is considerably faster than AES in software-only
# implementations, making it around three times as fast on
# platforms that lack specialized AES hardware.
# ChaCha20 is also immune to timing attacks.
class Crypto::ChaCha20
  # :nodoc:
  BLOCK_SIZE = 64

  # The inputs to ChaCha20 are:
  # * key: A 256-bit key, treated as a concatenation of eight 32-bit little-
  #   endian integers.
  # * nonce: A 96-bit nonce, treated as a concatenation of three 32-bit little-
  #   endian integers.
  # * counter: A 32-bit block count parameter, treated as a 32-bit little-endian
  #   integer.
  def initialize(key : Bytes, nonce : Bytes, counter : UInt32 = 0_u32)
    raise "key needs to be 32 bytes (256 bits)" unless key.size == 32
    raise "nonce needs to be 12 bytes (96 bits)" unless nonce.size == 12

    @state = uninitialized UInt32[16]

    # Constants
    @state[0] = 0x61707865
    @state[1] = 0x3320646e
    @state[2] = 0x79622d32
    @state[3] = 0x6b206574

    # Key
    @state[4] = IO::ByteFormat::LittleEndian.decode(UInt32, key[0, 4])
    @state[5] = IO::ByteFormat::LittleEndian.decode(UInt32, key[4, 4])
    @state[6] = IO::ByteFormat::LittleEndian.decode(UInt32, key[8, 4])
    @state[7] = IO::ByteFormat::LittleEndian.decode(UInt32, key[12, 4])
    @state[8] = IO::ByteFormat::LittleEndian.decode(UInt32, key[16, 4])
    @state[9] = IO::ByteFormat::LittleEndian.decode(UInt32, key[20, 4])
    @state[10] = IO::ByteFormat::LittleEndian.decode(UInt32, key[24, 4])
    @state[11] = IO::ByteFormat::LittleEndian.decode(UInt32, key[28, 4])

    # Counter
    @state[12] = counter

    # Nonce
    @state[13] = IO::ByteFormat::LittleEndian.decode(UInt32, nonce[0, 4])
    @state[14] = IO::ByteFormat::LittleEndian.decode(UInt32, nonce[4, 4])
    @state[15] = IO::ByteFormat::LittleEndian.decode(UInt32, nonce[8, 4])
  end

  # The inputs to ChaCha20 are:
  # * key: A 256-bit key, treated as a concatenation of eight 32-bit little-
  #   endian integers. (**hex encoded**)
  # * nonce: A 96-bit nonce, treated as a concatenation of three 32-bit little-
  #   endian integers. (**hex encoded**)
  # * counter: A 32-bit block count parameter, treated as a 32-bit little-endian
  #   integer.
  def initialize(key : String, nonce : String, counter : UInt32 = 0_u32)
    initialize(Crypto::Hex.bytes(key), Crypto::Hex.bytes(nonce), counter)
  end

  # Directly initialize using the state
  def initialize(state : UInt32[16])
    @state = uninitialized UInt32[16]
    16.times do |i|
      @state[i] = state[i]
    end
  end

  # Create a clone from the state
  def clone
    klone = self.class.new(@state)
    klone.reset
    klone
  end

  # encrypt the plaintext, returning the encrypted bytes
  def encrypt(plaintext : Bytes) : Bytes
    # caclulate block size based on plaintext
    size = plaintext.size + (BLOCK_SIZE - plaintext.size % BLOCK_SIZE)
    encrypted = Bytes.new(size, 0x00)
    encrypt(plaintext, encrypted)
    encrypted[0, plaintext.size]
  end

  # reads from plaintext and writes to encrypted
  def encrypt(plaintext : Bytes, encrypted : Bytes) : Nil
    raise "encrypted needs to be multiple of #{BLOCK_SIZE}" unless encrypted.size % BLOCK_SIZE == 0

    block_state = uninitialized UInt32[16]
    encrypted.copy_from(plaintext)

    (encrypted.size // BLOCK_SIZE).times do |pos|
      key_block = next_key_block(block_state).to_unsafe
      16.times do |i|
        offset = (pos &* BLOCK_SIZE) &+ (i &* 4)
        encrypted.to_unsafe[offset] ^= (key_block[i] >> 0) & 0xff_u8
        encrypted.to_unsafe[offset &+ 1] ^= (key_block[i] >> 8) & 0xff_u8
        encrypted.to_unsafe[offset &+ 2] ^= (key_block[i] >> 16) & 0xff_u8
        encrypted.to_unsafe[offset &+ 3] ^= (key_block[i] >> 24) & 0xff_u8
      end
    end
  end

  # reads from plaintext and writes to encrypted
  def encrypt(plaintext : IO, encrypted : IO)
    plaintext_block = uninitialized UInt8[16]
    encrypted_block = uninitialized UInt8[16]
    loop do
      n = plaintext.read(plaintext_block)
      break if n == 0
      encrypt(plaintext_block, encrypted_block)
      encrypted.write(encrypted_block.raw[0, n])
    end
  end

  # :nodoc:
  # returns the next key block
  def next_key_block(block_state : UInt32[16] = StaticArray(UInt32, 16).new(0u32)) : UInt32[16]
    # initialize block state
    block_state.to_slice.copy_from(@state.to_slice)

    # carry out inner blocks 10 times
    10.times do
      quarter_round(block_state.to_slice, 0, 4, 8, 12)
      quarter_round(block_state.to_slice, 1, 5, 9, 13)
      quarter_round(block_state.to_slice, 2, 6, 10, 14)
      quarter_round(block_state.to_slice, 3, 7, 11, 15)
      quarter_round(block_state.to_slice, 0, 5, 10, 15)
      quarter_round(block_state.to_slice, 1, 6, 11, 12)
      quarter_round(block_state.to_slice, 2, 7, 8, 13)
      quarter_round(block_state.to_slice, 3, 4, 9, 14)
    end

    # apply state to block state
    16.times do |i|
      block_state[i] &+= @state[i]
    end

    # increment block counter
    @state[12] &+= 1
    if @state[12] == 0
      raise "counter overflow, more then 256 GB encrypted"
    end

    block_state
  end

  private def quarter_round(state : Slice(UInt32), a, b, c, d)
    state[a] &+= state[b]
    state[d] = (state[d] ^ state[a]).rotate_left(16)
    state[c] &+= state[d]
    state[b] = (state[b] ^ state[c]).rotate_left(12)
    state[a] &+= state[b]
    state[d] = (state[d] ^ state[a]).rotate_left(8)
    state[c] &+= state[d]
    state[b] = (state[b] ^ state[c]).rotate_left(7)
  end

  # reset the counter
  def reset
    @state[12] = 0_u32
  end

  # :nodoc:
  # converts a block to bytes
  def self.block_bytes(block : UInt32[16], be : Bool = true) : Bytes
    block_bytes = Bytes.new(block.size &* 4)
    block.each_with_index do |val, i|
      block_slice = block_bytes[(i &* 4)..((i &+ 1) &* 4 &- 1)]
      if be
        IO::ByteFormat::BigEndian.encode(val, block_slice)
      else
        IO::ByteFormat::LittleEndian.encode(val, block_slice)
      end
    end
    block_bytes
  end
end
