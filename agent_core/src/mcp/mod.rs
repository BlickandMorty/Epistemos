#[cfg(feature = "pro-build")]
pub mod client;
pub mod url_servers;

#[cfg(test)]
mod tests {
    #[test]
    fn stdio_mcp_client_module_is_pro_gated() {
        let source = include_str!("mod.rs");
        assert!(
            source.contains("#[cfg(feature = \"pro-build\")]\npub mod client;"),
            "Tunnel B.2 stdio MCP client must only compile in pro-build"
        );
    }
}
