/**
 * Checks whether a string is a syntactically valid http or https URL.
 *
 * Parsing is delegated to the built-in `URL` class, so anything the platform
 * considers a legal URL structure is accepted.  Only the `http:` and `https:`
 * schemes are permitted; all other schemes (ftp, mailto, …) return `false`.
 *
 * @param input - The raw string to test.
 * @returns `true` when `input` is a valid http/https URL, `false` otherwise.
 *
 * @example
 * isValidHttpUrl("https://example.com")      // true
 * isValidHttpUrl("http://x.org/path?q=1")    // true
 * isValidHttpUrl("ftp://files.example.com")  // false
 * isValidHttpUrl("not a url")                // false
 * isValidHttpUrl("")                         // false
 */
export function isValidHttpUrl(input: string): boolean {
  try {
    const url = new URL(input);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch {
    return false;
  }
}

/**
 * Returns a canonical form of the given http/https URL suitable for
 * deduplication hashing (design decision D2).
 *
 * Normalisation steps applied, in order:
 * 1. Scheme and host are lowercased (the `URL` constructor does this
 *    automatically; recorded here for clarity).
 * 2. Default ports are stripped — port 80 for `http:`, port 443 for `https:`.
 * 3. A lone trailing slash on the path is removed (e.g. `"/"`→`""`), but only
 *    when the path is exactly `"/"` so that meaningful path segments are kept.
 * 4. Query parameters are sorted alphabetically by key, then re-serialised.
 * 5. The fragment (`#…`) is dropped entirely.
 *
 * @param input - A raw http or https URL string.
 * @returns The normalised URL string.
 * @throws {TypeError} If `input` is not a valid http/https URL.
 *
 * @example
 * normalizeUrl("HTTPS://Example.COM/")
 * // "https://example.com"
 *
 * normalizeUrl("http://example.com:80/path?b=2&a=1#frag")
 * // "http://example.com/path?a=1&b=2"
 *
 * normalizeUrl("https://example.com:443/page")
 * // "https://example.com/page"
 */
export function normalizeUrl(input: string): string {
  if (!isValidHttpUrl(input)) {
    throw new TypeError(`Not a valid http/https URL: "${input}"`);
  }

  const url = new URL(input);

  // Step 1 — scheme + host are already lowercased by the URL constructor.

  // Step 2 — strip default ports.
  if (
    (url.protocol === "http:" && url.port === "80") ||
    (url.protocol === "https:" && url.port === "443")
  ) {
    url.port = "";
  }

  // Step 3 — sort query parameters alphabetically by key.
  url.searchParams.sort();

  // Step 4 — drop the fragment.
  url.hash = "";

  // Step 5 — remove a trailing slash on the root path.
  // The URL class always serialises a path-less origin as "/" (e.g.
  // "https://example.com/"), so we strip the trailing slash from the
  // final string rather than mutating url.pathname (which would
  // immediately be reset to "/" by the URL parser).
  // The URL class always serialises with at least "/" as the path, so we
  // strip the trailing slash directly from the serialised string when the
  // path is exactly "/".  We replace "/<query-or-end>" rather than a bare
  // trailing "/" to avoid accidentally removing slashes inside path segments.
  const serialised = url.toString();
  const result =
    url.pathname === "/"
      ? serialised.replace(/\/(\?|$)/, "$1")
      : serialised;

  return result;
}
