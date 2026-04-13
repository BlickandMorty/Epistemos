use agent_core::channel_relay::{
    build_state, ensure_db_parent, parse_listen_addr, resolve_db_path, serve, DEFAULT_LISTEN_ADDR,
};

struct CliArgs {
    listen: String,
    db_path: Option<String>,
    token: Option<String>,
}

impl CliArgs {
    fn parse_from<I>(args: I) -> Result<Self, String>
    where
        I: IntoIterator<Item = String>,
    {
        let mut listen = DEFAULT_LISTEN_ADDR.to_string();
        let mut db_path: Option<String> = None;
        let mut token: Option<String> = None;
        let mut iter = args.into_iter();

        while let Some(arg) = iter.next() {
            match arg.as_str() {
                "--listen" => {
                    listen = iter
                        .next()
                        .ok_or_else(|| "missing value after --listen".to_string())?;
                }
                "--db" => {
                    db_path = Some(
                        iter.next()
                            .ok_or_else(|| "missing value after --db".to_string())?,
                    );
                }
                "--token" => {
                    token = Some(
                        iter.next()
                            .ok_or_else(|| "missing value after --token".to_string())?,
                    );
                }
                "--help" | "-h" => {
                    return Err(Self::usage());
                }
                other => {
                    return Err(format!("unknown argument '{other}'\n\n{}", Self::usage()));
                }
            }
        }

        Ok(Self {
            listen,
            db_path,
            token,
        })
    }

    fn usage() -> String {
        format!(
            "Usage: epistemos_channel_relay [--listen <host:port>] [--db <path>] [--token <bearer-token>]\n\
             Defaults:\n\
               --listen {DEFAULT_LISTEN_ADDR}\n\
               --db $EPISTEMOS_CHANNEL_RELAY_DB or ~/.epistemos/channel_relay.db\n\
               --token $EPISTEMOS_CHANNEL_RELAY_TOKEN"
        )
    }
}

#[tokio::main]
async fn main() {
    let cli = match CliArgs::parse_from(std::env::args().skip(1)) {
        Ok(cli) => cli,
        Err(message) => {
            let exit_code = if message.starts_with("Usage:") { 0 } else { 1 };
            if exit_code == 0 {
                println!("{message}");
            } else {
                eprintln!("{message}");
            }
            std::process::exit(exit_code);
        }
    };

    let db_path = resolve_db_path(cli.db_path.as_deref());
    if let Err(error) = ensure_db_parent(&db_path) {
        eprintln!("{error}");
        std::process::exit(1);
    }

    let listen_addr = match parse_listen_addr(&cli.listen) {
        Ok(addr) => addr,
        Err(error) => {
            eprintln!("{error}");
            std::process::exit(1);
        }
    };

    eprintln!(
        "Starting Epistemos channel relay on {listen_addr} using {}",
        db_path.display()
    );

    if let Err(error) = serve(listen_addr, build_state(Some(db_path), cli.token)).await {
        eprintln!("{error}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::CliArgs;
    use agent_core::channel_relay::DEFAULT_LISTEN_ADDR;

    #[test]
    fn cli_defaults_to_local_listen_addr() {
        let cli = CliArgs::parse_from(Vec::<String>::new()).unwrap();
        assert_eq!(cli.listen, DEFAULT_LISTEN_ADDR);
        assert!(cli.db_path.is_none());
        assert!(cli.token.is_none());
    }

    #[test]
    fn cli_parses_explicit_overrides() {
        let cli = CliArgs::parse_from(vec![
            "--listen".to_string(),
            "0.0.0.0:9999".to_string(),
            "--db".to_string(),
            "/tmp/relay.db".to_string(),
            "--token".to_string(),
            "secret".to_string(),
        ])
        .unwrap();
        assert_eq!(cli.listen, "0.0.0.0:9999");
        assert_eq!(cli.db_path.as_deref(), Some("/tmp/relay.db"));
        assert_eq!(cli.token.as_deref(), Some("secret"));
    }
}
