//! sample.rs — a sample Rust file for testing.
//!
//! A small, self-contained program showing common Rust constructs:
//! structs, enums, traits, generics, error handling with `Result`,
//! iterators, and a `#[cfg(test)]` module. Compile and run with:
//!
//! ```text
//! rustc sample.rs -o sample && ./sample
//! ```

use std::collections::HashMap;
use std::fmt;

/// A shape we can compute the area of.
trait Shape {
    fn area(&self) -> f64;
    fn name(&self) -> &'static str;
}

struct Circle {
    radius: f64,
}

struct Rectangle {
    width: f64,
    height: f64,
}

impl Shape for Circle {
    fn area(&self) -> f64 {
        std::f64::consts::PI * self.radius * self.radius
    }
    fn name(&self) -> &'static str {
        "circle"
    }
}

impl Shape for Rectangle {
    fn area(&self) -> f64 {
        self.width * self.height
    }
    fn name(&self) -> &'static str {
        "rectangle"
    }
}

/// Errors that can occur while parsing a key=value pair.
#[derive(Debug)]
enum ParseError {
    MissingDelimiter,
    EmptyKey,
}

impl fmt::Display for ParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ParseError::MissingDelimiter => write!(f, "missing '=' delimiter"),
            ParseError::EmptyKey => write!(f, "key is empty"),
        }
    }
}

/// Parse a single `key=value` string into a `(key, value)` pair.
fn parse_pair(input: &str) -> Result<(String, String), ParseError> {
    let (key, value) = input.split_once('=').ok_or(ParseError::MissingDelimiter)?;
    let key = key.trim();
    if key.is_empty() {
        return Err(ParseError::EmptyKey);
    }
    Ok((key.to_string(), value.trim().to_string()))
}

/// Parse many `key=value` lines into a map, skipping blanks and `#` comments.
fn parse_config(lines: &[&str]) -> Result<HashMap<String, String>, ParseError> {
    lines
        .iter()
        .map(|l| l.trim())
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .map(|l| parse_pair(l))
        .collect()
}

fn main() {
    let shapes: Vec<Box<dyn Shape>> = vec![
        Box::new(Circle { radius: 2.0 }),
        Box::new(Rectangle {
            width: 3.0,
            height: 4.0,
        }),
    ];

    let total: f64 = shapes.iter().map(|s| s.area()).sum();
    for shape in &shapes {
        println!("{:<10} area = {:.3}", shape.name(), shape.area());
    }
    println!("total area = {:.3}", total);

    let config = parse_config(&["# settings", "host = localhost", "port = 8080"]);
    match config {
        Ok(map) => println!("parsed {} config entries", map.len()),
        Err(e) => eprintln!("config error: {e}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn circle_area_is_pi_r_squared() {
        let c = Circle { radius: 1.0 };
        assert!((c.area() - std::f64::consts::PI).abs() < 1e-9);
    }

    #[test]
    fn parse_pair_trims_whitespace() {
        let (k, v) = parse_pair("  name = Ada  ").unwrap();
        assert_eq!(k, "name");
        assert_eq!(v, "Ada");
    }

    #[test]
    fn parse_pair_rejects_missing_delimiter() {
        assert!(matches!(
            parse_pair("noequals"),
            Err(ParseError::MissingDelimiter)
        ));
    }

    #[test]
    fn parse_config_skips_comments_and_blanks() {
        let map = parse_config(&["# c", "", "a = 1", "b = 2"]).unwrap();
        assert_eq!(map.len(), 2);
        assert_eq!(map.get("a"), Some(&"1".to_string()));
    }
}
