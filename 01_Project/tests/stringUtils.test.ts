import { describe, it, expect } from "vitest";
import { slugify, truncate, titleCase } from "../src/stringUtils";

// ---------------------------------------------------------------------------
// slugify
// ---------------------------------------------------------------------------

describe("slugify", () => {
  it("lowercases the input", () => {
    expect(slugify("Hello World")).toBe("hello-world");
  });

  it("replaces spaces with hyphens", () => {
    expect(slugify("foo bar baz")).toBe("foo-bar-baz");
  });

  it("removes characters that are not alphanumeric or spaces", () => {
    expect(slugify("Hello, World!")).toBe("hello-world");
  });

  it("collapses multiple spaces and hyphens into a single hyphen", () => {
    expect(slugify("foo   bar--baz")).toBe("foo-bar-baz");
  });

  it("trims leading and trailing whitespace", () => {
    expect(slugify("  hello world  ")).toBe("hello-world");
  });

  it("returns an empty string for an input that contains no valid characters", () => {
    expect(slugify("!!!")).toBe("");
  });

  it("handles an already-valid slug unchanged", () => {
    expect(slugify("already-slugged")).toBe("already-slugged");
  });
});

// ---------------------------------------------------------------------------
// truncate
// ---------------------------------------------------------------------------

describe("truncate", () => {
  it("returns the original string when it fits within max", () => {
    expect(truncate("Short", 10)).toBe("Short");
  });

  it("returns the original string when its length equals max exactly", () => {
    expect(truncate("12345", 5)).toBe("12345");
  });

  it("appends an ellipsis when the string exceeds max", () => {
    expect(truncate("Hello, world!", 8)).toBe("Hello...");
  });

  it("the truncated result is exactly max characters long", () => {
    const result = truncate("abcdefghij", 7);
    expect(result.length).toBe(7);
    expect(result).toBe("abcd...");
  });

  it("throws RangeError when max is less than 4", () => {
    expect(() => truncate("hi", 3)).toThrow(RangeError);
  });

  it("handles an empty string without error", () => {
    expect(truncate("", 10)).toBe("");
  });
});

// ---------------------------------------------------------------------------
// titleCase
// ---------------------------------------------------------------------------

describe("titleCase", () => {
  it("capitalises the first letter of each word", () => {
    expect(titleCase("hello world")).toBe("Hello World");
  });

  it("lowercases letters after the first in each word", () => {
    expect(titleCase("the QUICK brown FOX")).toBe("The Quick Brown Fox");
  });

  it("handles a single word", () => {
    expect(titleCase("typescript")).toBe("Typescript");
  });

  it("preserves internal whitespace between words", () => {
    expect(titleCase("one  two")).toBe("One  Two");
  });

  it("returns an empty string for empty input", () => {
    expect(titleCase("")).toBe("");
  });

  it("handles a string that is already in title case", () => {
    expect(titleCase("Already Title Case")).toBe("Already Title Case");
  });
});
