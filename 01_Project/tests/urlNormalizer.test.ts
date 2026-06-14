import { describe, it, expect } from "vitest";
import { isValidHttpUrl, normalizeUrl } from "../src/urlNormalizer";

// ---------------------------------------------------------------------------
// isValidHttpUrl
// ---------------------------------------------------------------------------

describe("isValidHttpUrl", () => {
  it("accepts a plain https URL", () => {
    expect(isValidHttpUrl("https://example.com")).toBe(true);
  });

  it("accepts a plain http URL", () => {
    expect(isValidHttpUrl("http://example.com")).toBe(true);
  });

  it("accepts an http URL with a path and query string", () => {
    expect(isValidHttpUrl("http://x.org/path?q=1")).toBe(true);
  });

  it("rejects a non-URL string", () => {
    expect(isValidHttpUrl("not a url")).toBe(false);
  });

  it("rejects an empty string", () => {
    expect(isValidHttpUrl("")).toBe(false);
  });

  it("rejects an ftp URL", () => {
    expect(isValidHttpUrl("ftp://files.example.com")).toBe(false);
  });

  it("rejects a mailto URI", () => {
    expect(isValidHttpUrl("mailto:user@example.com")).toBe(false);
  });

  it("rejects a bare domain with no scheme", () => {
    expect(isValidHttpUrl("example.com")).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// normalizeUrl — scheme and host lowercasing
// ---------------------------------------------------------------------------

describe("normalizeUrl — scheme and host lowercasing", () => {
  it("lowercases an uppercase scheme", () => {
    expect(normalizeUrl("HTTPS://example.com/page")).toBe(
      "https://example.com/page"
    );
  });

  it("lowercases an uppercase host", () => {
    expect(normalizeUrl("https://EXAMPLE.COM/page")).toBe(
      "https://example.com/page"
    );
  });

  it("lowercases a mixed-case scheme and host together", () => {
    expect(normalizeUrl("HTTP://Example.Org/")).toBe("http://example.org");
  });
});

// ---------------------------------------------------------------------------
// normalizeUrl — default-port removal
// ---------------------------------------------------------------------------

describe("normalizeUrl — default-port removal", () => {
  it("removes port 80 from an http URL", () => {
    expect(normalizeUrl("http://example.com:80/path")).toBe(
      "http://example.com/path"
    );
  });

  it("removes port 443 from an https URL", () => {
    expect(normalizeUrl("https://example.com:443/path")).toBe(
      "https://example.com/path"
    );
  });

  it("keeps a non-default port on http", () => {
    expect(normalizeUrl("http://example.com:8080/path")).toBe(
      "http://example.com:8080/path"
    );
  });

  it("keeps a non-default port on https", () => {
    expect(normalizeUrl("https://example.com:8443/path")).toBe(
      "https://example.com:8443/path"
    );
  });

  it("does not remove port 443 from an http URL", () => {
    expect(normalizeUrl("http://example.com:443/path")).toBe(
      "http://example.com:443/path"
    );
  });
});

// ---------------------------------------------------------------------------
// normalizeUrl — trailing-slash stripping
// ---------------------------------------------------------------------------

describe("normalizeUrl — trailing-slash stripping", () => {
  it("removes the trailing slash when the path is exactly '/'", () => {
    expect(normalizeUrl("https://example.com/")).toBe("https://example.com");
  });

  it("does not remove a trailing slash from a multi-segment path", () => {
    expect(normalizeUrl("https://example.com/a/b/")).toBe(
      "https://example.com/a/b/"
    );
  });

  it("does not alter a path with no trailing slash", () => {
    expect(normalizeUrl("https://example.com/page")).toBe(
      "https://example.com/page"
    );
  });
});

// ---------------------------------------------------------------------------
// normalizeUrl — query-parameter sorting
// ---------------------------------------------------------------------------

describe("normalizeUrl — query-parameter sorting", () => {
  it("sorts two query parameters alphabetically", () => {
    expect(normalizeUrl("https://example.com/?b=2&a=1")).toBe(
      "https://example.com?a=1&b=2"
    );
  });

  it("sorts three query parameters alphabetically", () => {
    expect(normalizeUrl("https://example.com/search?z=last&a=first&m=mid")).toBe(
      "https://example.com/search?a=first&m=mid&z=last"
    );
  });

  it("leaves an already-sorted query string unchanged", () => {
    expect(normalizeUrl("https://example.com/?a=1&b=2")).toBe(
      "https://example.com?a=1&b=2"
    );
  });

  it("handles a URL with no query string", () => {
    expect(normalizeUrl("https://example.com/page")).toBe(
      "https://example.com/page"
    );
  });
});

// ---------------------------------------------------------------------------
// normalizeUrl — fragment removal
// ---------------------------------------------------------------------------

describe("normalizeUrl — fragment removal", () => {
  it("drops a fragment from an otherwise plain URL", () => {
    expect(normalizeUrl("https://example.com/page#section")).toBe(
      "https://example.com/page"
    );
  });

  it("drops a fragment when a query string is also present", () => {
    expect(normalizeUrl("https://example.com/?q=1#top")).toBe(
      "https://example.com?q=1"
    );
  });

  it("does nothing extra when there is no fragment", () => {
    expect(normalizeUrl("https://example.com/page")).toBe(
      "https://example.com/page"
    );
  });
});

// ---------------------------------------------------------------------------
// normalizeUrl — combined normalisations and deduplication equivalence
// ---------------------------------------------------------------------------

describe("normalizeUrl — combined normalisations", () => {
  it("applies all rules in one pass", () => {
    expect(normalizeUrl("HTTP://Example.COM:80/?b=2&a=1#frag")).toBe(
      "http://example.com?a=1&b=2"
    );
  });

  it("two semantically equivalent URLs normalise to the same string", () => {
    const a = normalizeUrl("HTTPS://Example.COM:443/path?z=3&a=1#ignore");
    const b = normalizeUrl("https://example.com/path?a=1&z=3");
    expect(a).toBe(b);
  });
});

// ---------------------------------------------------------------------------
// normalizeUrl — invalid input
// ---------------------------------------------------------------------------

describe("normalizeUrl — invalid input throws TypeError", () => {
  it("throws for a plain string", () => {
    expect(() => normalizeUrl("not a url")).toThrow(TypeError);
  });

  it("throws for an empty string", () => {
    expect(() => normalizeUrl("")).toThrow(TypeError);
  });

  it("throws for an ftp URL", () => {
    expect(() => normalizeUrl("ftp://files.example.com")).toThrow(TypeError);
  });
});
