/**
 * Converts a string into a URL-friendly slug.
 *
 * Lowercases the input, strips characters that are not alphanumeric or
 * whitespace, collapses runs of whitespace/hyphens into a single hyphen,
 * and trims leading/trailing hyphens.
 *
 * @param input - The raw string to slugify.
 * @returns A lowercase, hyphen-separated slug.
 *
 * @example
 * slugify("Hello World!")  // "hello-world"
 * slugify("  Foo  Bar  ")  // "foo-bar"
 */
export function slugify(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, "")
    .trim()
    .replace(/[\s-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

/**
 * Truncates a string to at most `max` characters.
 *
 * If the string already fits within `max` it is returned unchanged.
 * Otherwise it is cut at `max - 3` characters and an ellipsis (`...`) is
 * appended so the total length equals `max`.
 *
 * @param input - The string to truncate.
 * @param max   - Maximum allowed character count (must be >= 4 to leave room
 *                for at least one visible character plus the ellipsis).
 * @returns The original string, or a truncated version ending in `...`.
 *
 * @example
 * truncate("Hello, world!", 8)   // "Hello..."
 * truncate("Short", 10)          // "Short"
 */
export function truncate(input: string, max: number): string {
  if (max < 4) {
    throw new RangeError("max must be at least 4");
  }
  if (input.length <= max) {
    return input;
  }
  return input.slice(0, max - 3) + "...";
}

/**
 * Converts a string to title case.
 *
 * Every word (sequence of non-whitespace characters) has its first character
 * uppercased and the remainder lowercased. Whitespace between words is
 * preserved as-is.
 *
 * @param input - The string to transform.
 * @returns The title-cased string.
 *
 * @example
 * titleCase("hello world")      // "Hello World"
 * titleCase("the QUICK brown")  // "The Quick Brown"
 */
export function titleCase(input: string): string {
  return input.replace(/\S+/g, (word) => {
    return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
  });
}
