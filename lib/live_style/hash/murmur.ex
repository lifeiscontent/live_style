defmodule LiveStyle.Hash.Murmur do
  @moduledoc """
  MurmurHash2 32-bit implementation for LiveStyle.

  This is a port of the JavaScript MurmurHash2 implementation used by StyleX.
  The algorithm produces stable, well-distributed 32-bit hashes suitable for
  generating short, unique class names.

  ## Algorithm

  MurmurHash2 is a non-cryptographic hash function designed for speed.
  It processes input in 4-byte chunks and produces a 32-bit hash.

  ## JavaScript Compatibility

  This implementation carefully matches JavaScript's bitwise semantics:
  - 32-bit signed integer conversions (like `|0`)
  - Unsigned right shift (`>>>`)
  - Multiplication with implicit truncation

  ## Example

      iex> LiveStyle.Hash.Murmur.hash("hello", 1)
      613153351
  """

  import Bitwise

  @doc """
  Computes the MurmurHash2 32-bit hash of a string.

  ## Parameters

    * `str` - The string to hash
    * `seed` - The seed value (default: 0)

  ## Returns

  A 32-bit unsigned integer hash value.

  ## Examples

      iex> LiveStyle.Hash.Murmur.hash("hello")
      1335831723

      iex> LiveStyle.Hash.Murmur.hash("hello", 1)
      613153351
  """
  @spec hash(String.t(), non_neg_integer()) :: non_neg_integer()
  def hash(str, seed \\ 0) do
    bytes = :binary.bin_to_list(str)
    len = length(bytes)

    # Initialize hash
    h = bxor(seed, len) |> band(0xFFFFFFFF)

    # Process 4-byte chunks
    {h, remaining} = process_chunks(bytes, h)

    # Process remaining bytes
    h = process_tail(remaining, h)

    # Final mixing
    h = js_xor(h, js_unsigned_shift(h, 13))
    h = js_multiply(h, 0x5BD1E995) |> band(0xFFFFFFFF)
    h = js_xor(h, js_unsigned_shift(h, 15))

    h
  end

  # Process 4-byte chunks
  defp process_chunks([b0, b1, b2, b3 | rest], h) do
    k =
      band(b0, 0xFF)
      |> bor(bsl(band(b1, 0xFF), 8))
      |> bor(bsl(band(b2, 0xFF), 16))
      |> bor(bsl(band(b3, 0xFF), 24))

    # JS-style multiplication (can produce values > 32-bit)
    k = js_multiply(k, 0x5BD1E995)
    # XOR: JS >>> treats value as 32-bit unsigned first
    k = js_xor(k, js_unsigned_shift(k, 24))
    k = js_multiply(k, 0x5BD1E995)

    h = js_multiply(h, 0x5BD1E995)
    h = js_xor(h, k)

    process_chunks(rest, h)
  end

  defp process_chunks(bytes, h), do: {h, bytes}

  # Process remaining bytes (tail)
  defp process_tail([], h), do: h

  defp process_tail([b0], h) do
    h = js_xor(h, band(b0, 0xFF))
    js_multiply(h, 0x5BD1E995)
  end

  defp process_tail([b0, b1], h) do
    h = js_xor(h, bsl(band(b1, 0xFF), 8))
    h = js_xor(h, band(b0, 0xFF))
    js_multiply(h, 0x5BD1E995)
  end

  defp process_tail([b0, b1, b2], h) do
    h = js_xor(h, bsl(band(b2, 0xFF), 16))
    h = js_xor(h, bsl(band(b1, 0xFF), 8))
    h = js_xor(h, band(b0, 0xFF))
    js_multiply(h, 0x5BD1E995)
  end

  # JavaScript-style unsigned right shift (>>>)
  # JS >>> treats the value as 32-bit unsigned BEFORE shifting
  defp js_unsigned_shift(n, bits) do
    band(n, 0xFFFFFFFF) >>> bits
  end

  # JavaScript-style XOR: converts operands to 32-bit signed, then XOR
  defp js_xor(a, b) do
    # Convert to 32-bit signed (like JS |0)
    a_32 = to_int32(a)
    b_32 = to_int32(b)
    # XOR and convert back to unsigned
    bxor(a_32, b_32) |> band(0xFFFFFFFF)
  end

  # Convert to 32-bit signed integer (like JS |0)
  defp to_int32(n) do
    n = band(n, 0xFFFFFFFF)
    if n >= 0x80000000, do: n - 0x100000000, else: n
  end

  # JavaScript-style multiplication for MurmurHash
  # In JS: (k & 0xffff) * m + ((((k >>> 16) * m) & 0xffff) << 16)
  # This can produce values > 32 bits, truncation happens on next bitwise op
  defp js_multiply(k, m) do
    # Ensure we start with 32-bit
    k = band(k, 0xFFFFFFFF)
    k_low = band(k, 0xFFFF)
    k_high = k >>> 16

    low_mult = k_low * m
    high_mult = k_high * m
    high_masked = band(high_mult, 0xFFFF)
    high_shifted = bsl(high_masked, 16)

    low_mult + high_shifted
  end
end
