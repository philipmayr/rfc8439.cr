class Crypto::TagException < Exception; end

# AEAD_CHACHA20_POLY1305 is an authenticated encryption with additional
# data algorithm.
class Crypto::AeadChacha20Poly1305
  # :nodoc:
  BLOCK_SIZE = 16

  # The inputs to AEAD_CHACHA20_POLY1305 are:
  # * key: A 256-bit key
  # * nonce: A 96-bit nonce -- different for each invocation with the same key
  # * io: the buffer to write the authenticated plain and ciphertext to
  def initialize(key : Bytes, nonce : Bytes, @io : IO)
    @cipher = Crypto::ChaCha20.new(key, nonce, 1)
    @mac = Crypto::Poly1305.chacha20(@cipher)
    @aad_size = 0_u64
    @plaintext_size = 0_u64
  end

  # Arbitrary length additional authenticated data (AAD).
  # Needs to be written before the plaintext. Can be called multiple
  # times, but only the last block can be less than 16 bytes.
  def aad(data : Bytes)
    @aad_size += data.size
    write(data)
  end

  # An arbitrary length plaintext- has to be multiples of 16 bytes.
  # Last call may be with fewer than 16 bytes.
  def update(data : Bytes)
    @plaintext_size += data.size
    write(@cipher.encrypt(data))
  end

  # write final footer
  def final : Bytes
    footer = uninitialized UInt8[BLOCK_SIZE]
    IO::ByteFormat::LittleEndian.encode(@aad_size, footer.to_slice[0..8])
    IO::ByteFormat::LittleEndian.encode(@plaintext_size, footer.to_slice[8..15])
    write(footer.to_slice)
    @mac.final
  end

  # decrypt parses the data and verifies the data with the tag
  # returning the additional authenticated data. The plaintext is
  # written to the provided mem; in case the tag is not validating
  # the data an exception is raised.
  def decrypt(data : Bytes, tag : Bytes) : Bytes
    # validate the tag
    @mac.update(data)
    cipher_tag = @mac.final
    if tag != cipher_tag
      raise TagException.new("mismatching tag for cipher text")
    end

    # read the footer
    footer = data[(data.size &- BLOCK_SIZE)..]
    aad_size = IO::ByteFormat::LittleEndian.decode(UInt64, footer[0..8])
    plaintext_size = IO::ByteFormat::LittleEndian.decode(UInt64, footer[8..15])

    # read the plaintext
    pad = aad_size % BLOCK_SIZE
    offset = aad_size
    offset += BLOCK_SIZE &- pad if pad != 0
    plaintext = data[offset...(offset &+ plaintext_size)]
    @io.write(@cipher.encrypt(plaintext))

    # AAD
    data[0..(aad_size &- 1)]
  end

  private def write(data : Bytes)
    pad = data.size % BLOCK_SIZE

    if data.size >= BLOCK_SIZE
      aligned_data = data[0..(data.size &- pad &- 1)]
      @io.write(aligned_data)
      @mac.update(aligned_data)
    end

    if pad > 0
      data_with_padding = Bytes.new(BLOCK_SIZE, 0_u8)
      remainder = data[(data.size &- pad)..]
      data_with_padding.copy_from(remainder)

      @io.write(data_with_padding)
      @mac.update(data_with_padding)
    end
  end
end
