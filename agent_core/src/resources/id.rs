use std::fmt;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, uniffi::Enum)]
pub enum ResourceId {
    VaultNote {
        vault_id: String,
        note_id: String,
    },
    File {
        absolute_path: String,
    },
    Chat {
        session_id: String,
        message_id: Option<String>,
    },
    Attachment {
        turn_id: String,
        attachment_id: String,
    },
    Model {
        provider: String,
        model_id: String,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum IdError {
    #[error("resource uri is empty")]
    Empty,
    #[error("unsupported resource uri: {0}")]
    Unsupported(String),
    #[error("missing resource component: {0}")]
    MissingComponent(&'static str),
}

impl ResourceId {
    pub fn parse(uri: &str) -> Result<Self, IdError> {
        let trimmed = uri.trim();
        if trimmed.is_empty() {
            return Err(IdError::Empty);
        }

        if let Some(rest) = trimmed.strip_prefix("vault://") {
            let (vault_id, note_id) = split_once(rest, "/note/", "vault note")?;
            return Ok(Self::VaultNote {
                vault_id: vault_id.to_string(),
                note_id: note_id.to_string(),
            });
        }

        if let Some(rest) = trimmed.strip_prefix("file://") {
            if rest.is_empty() {
                return Err(IdError::MissingComponent("absolute_path"));
            }
            return Ok(Self::File {
                absolute_path: rest.to_string(),
            });
        }

        if let Some(rest) = trimmed.strip_prefix("chat://") {
            let (session_id, message_id) = match rest.split_once("/message/") {
                Some((session_id, message_id)) => {
                    if session_id.is_empty() {
                        return Err(IdError::MissingComponent("session_id"));
                    }
                    if message_id.is_empty() {
                        return Err(IdError::MissingComponent("message_id"));
                    }
                    (session_id.to_string(), Some(message_id.to_string()))
                }
                None => {
                    if rest.is_empty() {
                        return Err(IdError::MissingComponent("session_id"));
                    }
                    (rest.to_string(), None)
                }
            };
            return Ok(Self::Chat {
                session_id,
                message_id,
            });
        }

        if let Some(rest) = trimmed.strip_prefix("attachment://") {
            let (turn_id, attachment_id) = split_once(rest, "/id/", "attachment")?;
            return Ok(Self::Attachment {
                turn_id: turn_id.to_string(),
                attachment_id: attachment_id.to_string(),
            });
        }

        if let Some(rest) = trimmed.strip_prefix("model://") {
            let (provider, model_id) = split_once(rest, "/id/", "model")?;
            return Ok(Self::Model {
                provider: provider.to_string(),
                model_id: model_id.to_string(),
            });
        }

        Err(IdError::Unsupported(trimmed.to_string()))
    }

    pub fn as_uri(&self) -> String {
        match self {
            Self::VaultNote { vault_id, note_id } => {
                format!("vault://{vault_id}/note/{note_id}")
            }
            Self::File { absolute_path } => format!("file://{absolute_path}"),
            Self::Chat {
                session_id,
                message_id,
            } => match message_id {
                Some(message_id) => format!("chat://{session_id}/message/{message_id}"),
                None => format!("chat://{session_id}"),
            },
            Self::Attachment {
                turn_id,
                attachment_id,
            } => format!("attachment://{turn_id}/id/{attachment_id}"),
            Self::Model { provider, model_id } => {
                format!("model://{provider}/id/{model_id}")
            }
        }
    }
}

fn split_once<'a>(
    value: &'a str,
    needle: &str,
    kind: &'static str,
) -> Result<(&'a str, &'a str), IdError> {
    let (left, right) = value
        .split_once(needle)
        .ok_or_else(|| IdError::Unsupported(format!("{kind}://{value}")))?;
    if left.is_empty() {
        return Err(IdError::MissingComponent(match kind {
            "vault note" => "vault_id",
            "attachment" => "turn_id",
            "model" => "provider",
            _ => "resource_id",
        }));
    }
    if right.is_empty() {
        return Err(IdError::MissingComponent(match kind {
            "vault note" => "note_id",
            "attachment" => "attachment_id",
            "model" => "model_id",
            _ => "resource_id",
        }));
    }
    Ok((left, right))
}

impl fmt::Display for ResourceId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.as_uri())
    }
}

#[cfg(test)]
mod tests {
    use super::ResourceId;

    #[test]
    fn parse_round_trips_resource_uris() {
        let ids = [
            ResourceId::VaultNote {
                vault_id: "main".into(),
                note_id: "daily-2026-04-23".into(),
            },
            ResourceId::File {
                absolute_path: "/Users/jojo/Downloads/Epistemos/README.md".into(),
            },
            ResourceId::Chat {
                session_id: "chat-123".into(),
                message_id: Some("msg-456".into()),
            },
            ResourceId::Attachment {
                turn_id: "turn-1".into(),
                attachment_id: "att-2".into(),
            },
            ResourceId::Model {
                provider: "openai".into(),
                model_id: "gpt-5.4".into(),
            },
        ];

        for id in ids {
            let uri = id.as_uri();
            assert_eq!(ResourceId::parse(&uri).unwrap(), id);
        }
    }

    #[test]
    fn chat_session_uri_without_message_round_trips() {
        let id = ResourceId::Chat {
            session_id: "chat-123".into(),
            message_id: None,
        };
        assert_eq!(ResourceId::parse(&id.as_uri()).unwrap(), id);
    }
}
