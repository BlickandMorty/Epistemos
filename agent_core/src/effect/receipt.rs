use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

#[derive(Serialize, Clone, Debug, PartialEq, Eq)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
pub enum Capability {
    VaultPath { path: String, verb: String },
    NetworkHost { host: String },
    BiometricSession { ttl_secs: u32 },
    Other { name: String },
}

#[derive(Deserialize)]
#[serde(
    deny_unknown_fields,
    tag = "kind",
    content = "value",
    rename_all = "snake_case"
)]
enum CapabilityWire {
    VaultPath(CapabilityVaultPathWire),
    NetworkHost(CapabilityNetworkHostWire),
    BiometricSession(CapabilityBiometricSessionWire),
    Other(CapabilityOtherWire),
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct CapabilityVaultPathWire {
    path: String,
    verb: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct CapabilityNetworkHostWire {
    host: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct CapabilityBiometricSessionWire {
    ttl_secs: u32,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct CapabilityOtherWire {
    name: String,
}

impl<'de> Deserialize<'de> for Capability {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        Ok(match CapabilityWire::deserialize(deserializer)? {
            CapabilityWire::VaultPath(wire) => Self::VaultPath {
                path: wire.path,
                verb: wire.verb,
            },
            CapabilityWire::NetworkHost(wire) => Self::NetworkHost { host: wire.host },
            CapabilityWire::BiometricSession(wire) => Self::BiometricSession {
                ttl_secs: wire.ttl_secs,
            },
            CapabilityWire::Other(wire) => Self::Other { name: wire.name },
        })
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct ExecutionReceipt {
    pub call_id: String,
    pub plan_hash: String,
    pub tool: String,
    pub input_hash: String,
    pub output_hash: String,
    pub timestamp: DateTime<Utc>,
    pub capabilities_used: Vec<Capability>,
    pub signature: String,
}

impl ExecutionReceipt {
    pub fn sign<K: SigningKey>(
        call_id: impl Into<String>,
        plan_hash: impl Into<String>,
        tool: impl Into<String>,
        input_bytes: &[u8],
        output_bytes: &[u8],
        capabilities_used: Vec<Capability>,
        key: &K,
    ) -> Self {
        let mut receipt = Self {
            call_id: call_id.into(),
            plan_hash: plan_hash.into(),
            tool: tool.into(),
            input_hash: sha256_hex(input_bytes),
            output_hash: sha256_hex(output_bytes),
            timestamp: Utc::now(),
            capabilities_used,
            signature: String::new(),
        };
        receipt.signature = hex_encode(&key.sign(&receipt.canonical_signing_payload()));
        receipt
    }

    pub fn verify<K: SigningKey>(&self, key: &K) -> bool {
        let Some(signature) = hex_decode(&self.signature) else {
            return false;
        };
        key.verify(&self.canonical_signing_payload(), &signature)
    }

    fn canonical_signing_payload(&self) -> Vec<u8> {
        let mut buf = Vec::with_capacity(256 + self.capabilities_used.len() * 64);
        write_field(&mut buf, b"call_id", self.call_id.as_bytes());
        write_field(&mut buf, b"plan_hash", self.plan_hash.as_bytes());
        write_field(&mut buf, b"tool", self.tool.as_bytes());
        write_field(&mut buf, b"input_hash", self.input_hash.as_bytes());
        write_field(&mut buf, b"output_hash", self.output_hash.as_bytes());
        let timestamp = self.timestamp.to_rfc3339();
        write_field(&mut buf, b"timestamp", timestamp.as_bytes());
        for (index, capability) in self.capabilities_used.iter().enumerate() {
            let key = format!("capability_{index}");
            let value = serde_json::to_vec(capability).unwrap_or_default();
            write_field(&mut buf, key.as_bytes(), &value);
        }
        buf
    }
}

pub trait SigningKey: Send + Sync {
    fn sign(&self, payload: &[u8]) -> Vec<u8>;
    fn verify(&self, payload: &[u8], signature: &[u8]) -> bool;
}

pub struct HmacSha256SigningKey {
    secret: [u8; 32],
}

impl HmacSha256SigningKey {
    pub fn new(secret: [u8; 32]) -> Self {
        Self { secret }
    }

    fn mac(&self, payload: &[u8]) -> [u8; 32] {
        const BLOCK_SIZE: usize = 64;
        let mut key_block = [0u8; BLOCK_SIZE];
        key_block[..self.secret.len()].copy_from_slice(&self.secret);

        let mut inner_pad = [0x36u8; BLOCK_SIZE];
        let mut outer_pad = [0x5cu8; BLOCK_SIZE];
        for index in 0..BLOCK_SIZE {
            inner_pad[index] ^= key_block[index];
            outer_pad[index] ^= key_block[index];
        }

        let mut inner = Sha256::new();
        inner.update(inner_pad);
        inner.update(payload);
        let inner_hash = inner.finalize();

        let mut outer = Sha256::new();
        outer.update(outer_pad);
        outer.update(inner_hash);
        outer.finalize().into()
    }
}

impl SigningKey for HmacSha256SigningKey {
    fn sign(&self, payload: &[u8]) -> Vec<u8> {
        self.mac(payload).to_vec()
    }

    fn verify(&self, payload: &[u8], signature: &[u8]) -> bool {
        let expected = self.mac(payload);
        if signature.len() != expected.len() {
            return false;
        }
        let mut diff = 0u8;
        for index in 0..signature.len() {
            diff |= signature[index] ^ expected[index];
        }
        diff == 0
    }
}

fn write_field(buf: &mut Vec<u8>, name: &[u8], value: &[u8]) {
    buf.extend_from_slice(&(name.len() as u32).to_le_bytes());
    buf.extend_from_slice(name);
    buf.extend_from_slice(&(value.len() as u32).to_le_bytes());
    buf.extend_from_slice(value);
}

fn sha256_hex(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

fn hex_encode(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push(HEX[(byte >> 4) as usize] as char);
        out.push(HEX[(byte & 0x0f) as usize] as char);
    }
    out
}

fn hex_decode(value: &str) -> Option<Vec<u8>> {
    if !value.len().is_multiple_of(2) {
        return None;
    }
    let mut out = Vec::with_capacity(value.len() / 2);
    for pair in value.as_bytes().chunks_exact(2) {
        let high = hex_nybble(pair[0])?;
        let low = hex_nybble(pair[1])?;
        out.push((high << 4) | low);
    }
    Some(out)
}

fn hex_nybble(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte - b'0'),
        b'a'..=b'f' => Some(byte - b'a' + 10),
        b'A'..=b'F' => Some(byte - b'A' + 10),
        _ => None,
    }
}
