# rfc8439

Pure* crystal implementation **ChaCha20** stream cipher as well as the **Poly1305** authenticator defined in rfc8439.
(* uses BigInt and therefore `gmp`)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     rfc8439:
       github: threez/rfc8439.cr
   ```

2. Run `shards install`

## Usage

### ChaCha20

```crystal
require "rfc8439"

# key and nonce are usually given using Bytes,
# but for convenience can be done as a hex string
key = "00:01:02:03:04:05:06:07:08:09:0a:0b:0c:0d:0e:0f:10:11:12:13:14:15:16:17:18:19:1a:1b:1c:1d:1e:1f"
nonce = "00:00:00:09:00:00:00:4a:00:00:00:00"
msg = "Hello World".to_slice

cipher = Crypto::ChaCha20.new(key, nonce)
encrypted = cipher.encrypt(msg)

# encryption is done using XOR so decryption is done
# by encrypting the cypher text
cipher = Crypto::ChaCha20.new(key, nonce)
plaintext = cipher.encrypt(encrypted)

puts plaintext
```

### Poly1305

```crystal
require "rfc8439"

key = "85:d6:be:78:57:55:6d:33:7f:44:52:fe:42:d5:06:a8:01:03:80:8a:fb:0d:b2:fd:4a:bf:f6:af:41:49:f5:1b"
msg = "Cryptographic Forum Research Group".to_slice

mac = Crypto::Poly1305.new(key)
mac.update(msg)
tag = mac.final

puts tag
```

### AEADChaCha20Poly1305

Writes the cipher text to `ciphertext` an `IO` target and returns the
16 byte (128 bit) Tag for the text.

```crystal
require "rfc8439"

key = Crypto::Hex.bytes("00:01:02:03:04:05:06:07:08:09:0a:0b:0c:0d:0e:0f:10:11:12:13:14:15:16:17:18:19:1a:1b:1c:1d:1e:1f")
nonce = Crypto::Hex.bytes("00:00:00:09:00:00:00:4a:00:00:00:00")
ciphertext = IO::Memory.new
aead = Crypto::AeadChacha20Poly1305.new(key, nonce, ciphertext)
aead.aad("Header".to_slice)
aead.update("Hello World!".to_slice)
tag = aead.final

puts tag
```

## Contributing

1. Fork it (<https://github.com/threez/rfc8439/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Vincent Landgraf](https://github.com/threez) - creator and maintainer
