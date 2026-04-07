// Single-line comment
/* Multi-line comment
   spanning multiple lines */

// Modules and imports
use std::collections::HashMap;
use std::fmt::{self, Display, Formatter};
use tokio::sync::mpsc;

// Macros / preprocessor equivalent
#[derive(Debug, Clone, PartialEq)]
#[allow(dead_code)]
pub struct Config {
    pub host: String,
    pub port: u16,
    pub retries: u32,
}

// Constants
const MAX_CONNECTIONS: usize = 128;
const DEFAULT_TIMEOUT: f64 = 30.0;

// Enum with variants
#[derive(Debug)]
pub enum AppError {
    Io(std::io::Error),
    Parse(String),
    Timeout { after_ms: u64 },
}

impl Display for AppError {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        match self {
            AppError::Io(e) => write!(f, "IO error: {e}"),
            AppError::Parse(msg) => write!(f, "Parse error: {msg}"),
            AppError::Timeout { after_ms } => write!(f, "Timed out after {after_ms}ms"),
        }
    }
}

// Generic struct with lifetime
pub struct Cache<'a, K, V> {
    data: HashMap<K, V>,
    label: &'a str,
}

impl<'a, K: Eq + std::hash::Hash, V> Cache<'a, K, V> {
    // Constructor
    pub fn new(label: &'a str) -> Self {
        Self { data: HashMap::new(), label }
    }

    pub fn insert(&mut self, key: K, value: V) -> Option<V> {
        self.data.insert(key, value)
    }
}

// Trait definition
pub trait Processor: Send + Sync {
    fn process(&self, input: &str) -> Result<String, AppError>;
    fn name(&self) -> &str;
}

// Async function with error handling
pub async fn fetch_data(url: &str, retries: u32) -> Result<Vec<u8>, AppError> {
    let client = reqwest::Client::new();
    let mut attempt = 0u32;

    loop {
        match client.get(url).send().await {
            Ok(resp) => {
                let bytes = resp.bytes().await.map_err(AppError::Io)?;
                return Ok(bytes.to_vec());
            }
            Err(_) if attempt < retries => {
                attempt += 1;
            }
            Err(e) => return Err(AppError::Parse(e.to_string())),
        }
    }
}

// Closures, iterators, string escapes
fn transform(items: &[&str]) -> Vec<String> {
    let prefix = "item";
    let raw = r#"raw\nstring"#;
    let escaped = "line1\nline2\ttabbed \"quoted\"";

    items
        .iter()
        .filter(|s| !s.is_empty())
        .map(|s| format!("{prefix}::{s} [{raw}] {escaped}"))
        .collect()
}

// Operator showcase: arithmetic, comparison, logical, range, ?
fn calculate(a: i64, b: i64) -> Option<i64> {
    if a == 0 || b < 0 {
        return None;
    }
    let result = (a + b) * (a - b) / (a % b.max(1));
    Some(result >> 2 & 0xFF)
}

fn main() {
    let mut cache: Cache<String, u64> = Cache::new("counters");
    cache.insert("alpha".to_string(), 1);
    cache.insert("beta".to_string(), 2);

    let words = vec!["hello", "", "world"];
    let out = transform(&words);
    println!("{out:?}");

    let val = calculate(10, 3).unwrap_or(0);
    println!("result = {val}");

    // Closures and self
    let adder = |x: i64| -> i64 { x + MAX_CONNECTIONS as i64 };
    println!("{}", adder(val));
}
