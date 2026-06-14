import { describe, it, expect } from "vitest";
import { encode, decode } from "../src/base62";

// ---------------------------------------------------------------------------
// encode
// ---------------------------------------------------------------------------

describe("encode", () => {
  it("encodes 0 to the string '0'", () => {
    expect(encode(0)).toBe("0");
  });

  it("encodes 9 (last single digit) to '9'", () => {
    expect(encode(9)).toBe("9");
  });

  it("encodes 10 to 'A' (first uppercase letter)", () => {
    expect(encode(10)).toBe("A");
  });

  it("encodes 35 to 'Z' (last uppercase letter)", () => {
    expect(encode(35)).toBe("Z");
  });

  it("encodes 36 to 'a' (first lowercase letter)", () => {
    expect(encode(36)).toBe("a");
  });

  it("encodes 61 to 'z' (last single-character code)", () => {
    expect(encode(61)).toBe("z");
  });

  it("encodes 62 to '10' (first two-character code)", () => {
    expect(encode(62)).toBe("10");
  });

  it("encodes 63 to '11'", () => {
    expect(encode(63)).toBe("11");
  });

  it("encodes a larger value correctly", () => {
    // 62^2 = 3844 should encode to "100"
    expect(encode(3844)).toBe("100");
  });

  it("throws RangeError for a negative integer", () => {
    expect(() => encode(-1)).toThrow(RangeError);
  });

  it("throws RangeError for a float", () => {
    expect(() => encode(1.5)).toThrow(RangeError);
  });

  it("throws RangeError for NaN", () => {
    expect(() => encode(NaN)).toThrow(RangeError);
  });
});

// ---------------------------------------------------------------------------
// decode
// ---------------------------------------------------------------------------

describe("decode", () => {
  it("decodes '0' to 0", () => {
    expect(decode("0")).toBe(0);
  });

  it("decodes 'z' to 61", () => {
    expect(decode("z")).toBe(61);
  });

  it("decodes '10' to 62", () => {
    expect(decode("10")).toBe(62);
  });

  it("decodes '100' to 3844", () => {
    expect(decode("100")).toBe(3844);
  });

  it("throws RangeError for an empty string", () => {
    expect(() => decode("")).toThrow(RangeError);
  });

  it("throws RangeError for a character outside the alphabet", () => {
    expect(() => decode("abc!")).toThrow(RangeError);
  });

  it("throws RangeError for a space character", () => {
    expect(() => decode("1 0")).toThrow(RangeError);
  });
});

// ---------------------------------------------------------------------------
// encode / decode round-trip
// ---------------------------------------------------------------------------

describe("encode/decode round-trip", () => {
  const cases = [0, 1, 9, 10, 35, 36, 61, 62, 63, 3844, 100_000, 9_999_999];

  for (const n of cases) {
    it(`round-trips ${n}`, () => {
      expect(decode(encode(n))).toBe(n);
    });
  }
});
