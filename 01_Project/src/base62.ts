const ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
const BASE = ALPHABET.length; // 62

/**
 * Encodes a non-negative integer to a base62 string.
 *
 * The alphabet used is `[0-9A-Za-z]` (digits first, then uppercase, then
 * lowercase), which matches the design decision D1 in the URL-shortener
 * design document. The encoding is length-minimal: `encode(0)` returns `"0"`,
 * `encode(62)` returns `"10"`.
 *
 * @param n - A non-negative integer to encode. Must be a safe integer (i.e.
 *            `Number.isSafeInteger(n)` must be `true`).
 * @returns A non-empty base62 string representation of `n`.
 * @throws {RangeError} If `n` is negative or not an integer.
 *
 * @example
 * encode(0)   // "0"
 * encode(61)  // "z"
 * encode(62)  // "10"
 * encode(3844) // "100"
 */
export function encode(n: number): string {
  if (!Number.isInteger(n)) {
    throw new RangeError(`encode expects an integer, got ${n}`);
  }
  if (n < 0) {
    throw new RangeError(`encode expects a non-negative integer, got ${n}`);
  }

  if (n === 0) {
    return "0";
  }

  let result = "";
  let remaining = n;
  while (remaining > 0) {
    result = ALPHABET[remaining % BASE] + result;
    remaining = Math.floor(remaining / BASE);
  }
  return result;
}

/**
 * Decodes a base62 string back to the integer it represents.
 *
 * This is the inverse of {@link encode}. Every character in `s` must belong
 * to the alphabet `[0-9A-Za-z]`.
 *
 * @param s - A non-empty base62 string produced by {@link encode}.
 * @returns The non-negative integer represented by `s`.
 * @throws {RangeError} If `s` is empty or contains a character outside the
 *                      base62 alphabet.
 *
 * @example
 * decode("0")   // 0
 * decode("z")   // 61
 * decode("10")  // 62
 * decode("100") // 3844
 */
export function decode(s: string): number {
  if (s.length === 0) {
    throw new RangeError("decode expects a non-empty string");
  }

  let result = 0;
  for (const char of s) {
    const digit = ALPHABET.indexOf(char);
    if (digit === -1) {
      throw new RangeError(
        `decode encountered invalid character '${char}' not in base62 alphabet`,
      );
    }
    result = result * BASE + digit;
  }
  return result;
}
