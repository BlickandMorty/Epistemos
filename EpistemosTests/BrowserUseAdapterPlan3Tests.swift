import Foundation
import Testing

@Suite("Plan 3 browser-use agent-browser adapter")
struct BrowserUseAdapterPlan3Tests {
    @Test("adapter speaks the existing agent-browser JSON contract")
    func adapterSpeaksExistingAgentBrowserJSONContract() throws {
        let source = try loadMirroredSourceTextFile("agent_core/vendor/browser-use/epistemos_agent_browser.py")

        for required in [
            "SUPPORTED_COMMANDS",
            "\"open\"",
            "\"snapshot\"",
            "\"click\"",
            "\"fill\"",
            "\"scroll\"",
            "\"back\"",
            "\"press\"",
            "\"close\"",
            "\"eval\"",
            "\"screenshot\"",
            "\"console\"",
            "\"errors\"",
            "parser.add_argument(\"--session\"",
            "parser.add_argument(\"--cdp\"",
            "parser.add_argument(\"--json\"",
            "split_adapter_argv",
            "parsed.args = command_args",
            "class JSONArgumentParser",
            "invalid browser-use adapter arguments",
            "command = \"unknown\"",
            "{\"success\": True, \"data\": data}",
            "json.dumps(response",
            "extract_refs",
            "MAX_REF_DIGITS",
            "@<browser-use-selector-index>",
        ] {
            #expect(source.contains(required), "Missing browser-use adapter contract string: \(required)")
        }
    }

    @Test("adapter delegates to browser-use CLI daemon without importing runtime for contract checks")
    func adapterDelegatesToBrowserUseCLIDaemon() throws {
        let source = try loadMirroredSourceTextFile("agent_core/vendor/browser-use/epistemos_agent_browser.py")

        for required in [
            "importlib.import_module(\"browser_use.skill_cli.main\")",
            "runtime.ensure_daemon",
            "runtime.send_command",
            "runtime._probe_session",
            "AGENT_BROWSER_SOCKET_DIR",
            "BROWSER_USE_HOME",
            "MAX_SESSION_NAME_LENGTH = 64",
            "invalid session name: at most 64 characters are allowed",
            "os.environ[\"BROWSER_USE_HOME\"]",
            "resolve_private_runtime_directory",
            "AGENT_BROWSER_SOCKET_DIR must be an absolute path",
            "reject_symlinked_runtime_path",
            "allowed_macos_compat_symlink",
            "validate_private_runtime_directory",
            "AGENT_BROWSER_SOCKET_DIR must not include symlink component",
            "AGENT_BROWSER_SOCKET_DIR must be owner-only",
            "AGENT_BROWSER_SCREENSHOT_DIR",
            "AGENT_BROWSER_SCREENSHOT_DIR must be owner-only",
            "confine_screenshot_path",
            "screenshot path resolved outside private screenshot directory",
            "screenshot returned non-string path",
            "write_screenshot_bytes",
            "screenshot returned invalid base64 image bytes",
            "screenshot returned non-PNG image bytes",
            "screenshot did not create requested output path",
            "screenshot accepts only one output path",
            "normalize_screenshot_size",
            "is_json_number",
            "math.isfinite",
            "require_exact_args",
            "require_no_args",
            "require_only_flags",
            "open accepts exactly one url",
            "fill accepts exactly a ref and text",
            "\"typed\": True",
            "\"typed_chars\": len(text)",
            "\"pressed\": True",
            "\"key_chars\": len(key)",
            "sanitize_output_url",
            "MAX_URL_OUTPUT_CHARS",
            "truncate_url_output",
            "MAX_ERROR_OUTPUT_CHARS",
            "sanitize_error_message",
            "exit_detail = sanitize_error_message",
            "SECRET_ASSIGNMENT_PATTERN",
            "BEARER_PATTERN",
            "\"url_redacted\"",
            "validate_cdp_url(parsed.cdp)",
            "def validate_cdp_url",
            "--cdp must point at localhost, 127.0.0.1, or [::1]",
            "--cdp must not include username or password credentials",
            "--cdp must not include a URL query",
            "--cdp must not include a URL fragment",
            "console does not accept argument",
            "console/errors compatibility stubs avoid browser-use runtime import",
            "return success({\"messages\": []})",
            "return success({\"errors\": []})",
            "value.startswith(\"--json=\")",
            "add_vendor_source_path(\"browser-use\")",
            "add_vendor_source_path(\"cdp-use\")",
            "browser-use adapter payload is not staged",
            "SNAPSHOT_CHAR_CAP",
            "MAX_SNAPSHOT_REFS",
            "MAX_EVAL_RESULT_TEXT_CHARS",
            "truncate_snapshot_text",
            "extract_refs(snapshot)",
            "\"refs_truncated\": refs_truncated or truncated",
            "raw_text if isinstance(raw_text, str) else \"\"",
            "bound_eval_result",
            "[Unsupported non-JSON result]",
            "[Unsupported non-finite number]",
            "\"result_truncated\"",
            "\"refs_truncated\"",
            "ensure_browser_daemon(args)\n        data = send_browser_use(\"open\"",
            "ensure_browser_daemon(args)\n    data = send_browser_use(\"state\"",
            "ensure_browser_daemon(args)\n    data = send_browser_use(\"screenshot\"",
            "send_browser_use(\"state\"",
            "send_browser_use(\"input\"",
            "send_browser_use(\"keys\"",
            "runtime.send_command(\"shutdown\"",
            "def ensure_browser_daemon(args",
            "def send_browser_use(action",
            "def close_session(name",
        ] {
            #expect(source.contains(required), "Missing browser-use daemon delegation string: \(required)")
        }
        #expect(!source.contains("ensure_browser_daemon(args)\n\n    if command == \"open\""))
        #expect(!source.contains("setdefault(\"BROWSER_USE_HOME\""))
        #expect(!source.contains("prepare_runtime_environment()\n\n    if command == \"close\""))
        #expect(!source.contains("\"typed\": text"))
        #expect(!source.contains("\"pressed\": key"))
        #expect(!source.contains("return success({\"url\": data.get(\"url\", url)})"))
        #expect(!source.contains("return success({\"result\": data.get(\"result\")})"))

        let contractIndex = try #require(source.range(of: "if command == \"contract\"")?.lowerBound)
        let prepareIndex = try #require(source.range(of: "prepare_runtime_environment()")?.lowerBound)
        #expect(contractIndex < prepareIndex)
        let ensureIndex = try #require(source.range(of: "def ensure_browser_daemon")?.lowerBound)
        let runtimePrepareIndex = try #require(source.range(of: "def ensure_browser_daemon(args: argparse.Namespace) -> None:\n    prepare_runtime_environment()")?.lowerBound)
        #expect(ensureIndex == runtimePrepareIndex)

        let consoleIndex = try #require(source.range(of: "if command == \"console\"")?.lowerBound)
        let errorsIndex = try #require(source.range(of: "if command == \"errors\"")?.lowerBound)
        let unsupportedIndex = try #require(source.range(of: "raise AdapterError(f\"unsupported browser-use adapter command")?.lowerBound)
        for branch in [String(source[consoleIndex..<errorsIndex]), String(source[errorsIndex..<unsupportedIndex])] {
            #expect(branch.contains("require_only_flags(command, args.args, {\"--clear\"})"))
            #expect(!branch.contains("ensure_browser_daemon"))
            #expect(!branch.contains("send_browser_use"))
            #expect(!branch.contains("prepare_runtime_environment"))
            #expect(!branch.contains("import_browser_use_main"))
        }
    }

    @Test("adapter stays inside Plan 3 browser-use vendor boundary")
    func adapterStaysInsidePlan3BrowserUseVendorBoundary() throws {
        let source = try loadMirroredSourceTextFile("agent_core/vendor/browser-use/epistemos_agent_browser.py")
        let manifest = try loadMirroredSourceTextFile("agent_core/vendor/browser-use/VENDOR_MANIFEST.json")
        let codepack = try loadMirroredSourceTextFile("docs/research/PLAN_3_BROWSER_USE_CODEPACK_2026_06_28.md")

        #expect(manifest.contains("\"agent_browser_adapter\""))
        #expect(manifest.contains("\"expected_path\": \"epistemos_agent_browser.py\""))
        #expect(manifest.contains("existing agent-browser JSON command contract"))
        #expect(codepack.contains("epistemos_agent_browser.py"))
        #expect(codepack.contains("adapter contract landed"))
        #expect(codepack.contains("console/errors compatibility stubs avoid browser-use runtime import"))

        for forbidden in [
            "Epistemos/Goose",
            "Epistemos/Agent",
            "BrowserView(",
            "BrowserURLGuard",
            "WebKitBrowserEngine",
            "ObscuraBrowserEngine",
            "HTMLWorkspace",
            "PDFView",
            "EpdocWebViewShared",
            "UserDefaults",
            "@AppStorage",
        ] {
            #expect(!source.contains(forbidden), "browser-use adapter crossed boundary: \(forbidden)")
        }
    }

    @Test("Rust browser tools discover the bundled browser-use adapter before PATH fallback")
    func rustBrowserToolsDiscoverBundledAdapterBeforePathFallback() throws {
        let browserTool = try loadMirroredSourceTextFile("agent_core/src/tools/browser.rs")
        let browserCommand = try loadMirroredSourceTextFile("agent_core/src/tools/browser_command.rs")
        let browserExecutable = try loadMirroredSourceTextFile("agent_core/src/tools/browser_executable.rs")
        let browserInput = try loadMirroredSourceTextFile("agent_core/src/tools/browser_input.rs")
        let browserOutput = try loadMirroredSourceTextFile("agent_core/src/tools/browser_output.rs")
        let browserPrivate = try loadMirroredSourceTextFile("agent_core/src/tools/browser_private.rs")
        let browserRedaction = try loadMirroredSourceTextFile("agent_core/src/tools/browser_redaction.rs")
        let browserSchema = try loadMirroredSourceTextFile("agent_core/src/tools/browser_schema.rs")
        let browserScreenshot = try loadMirroredSourceTextFile("agent_core/src/tools/browser_screenshot.rs")
        let registry = try loadMirroredSourceTextFile("agent_core/src/tools/registry.rs")

        for required in [
            "cdp_url_from_env",
            "run_agent_browser_command",
            "browser_screenshot_exports_private_root_to_adapter",
            "path_resolves_inside",
            "browser screenshot resolved outside private screenshot directory",
            "\"typed\": true",
            "\"typed_chars\"",
            "browser_type_result_does_not_echo_typed_text",
            "\"pressed\": true",
            "\"key_chars\"",
            "browser_press_result_does_not_echo_key_text",
            "cleanup_screenshot_file(&actual_path)",
            "\"screenshot_captured\"",
            "\"screenshot_retained\"",
            "sanitize_url_for_output",
            "\"url_redacted\"",
            "browser_navigate_result_redacts_url_query_and_fragment",
            "browser_cdp_commands_still_pass_private_session_name",
            "GET_IMAGES_PAGE_LIMIT",
            "GET_IMAGES_TEXT_LIMIT",
            "\"result_truncated\"",
            "browser_get_images_preserves_page_truncation_flag",
            "browser_console_preserves_adapter_eval_truncation_flag",
            "adapter_refs_truncated",
            "adapter_element_count",
            "browser_snapshot_preserves_adapter_truncation_flags",
        ] {
            #expect(browserTool.contains(required), "Missing Rust browser-use bridge string: \(required)")
        }
        #expect(!browserTool.contains("\"screenshot_path\".to_string()"))

        for required in [
            "find_agent_browser",
            "socket_dir_for_session",
            "read_limited_browser_output",
            "decode_limited_browser_output",
            "MAX_BROWSER_OUTPUT_BYTES",
            "was not valid UTF-8",
            "AGENT_BROWSER_SOCKET_DIR",
            "AGENT_BROWSER_SCREENSHOT_DIR_ENV",
            "screenshot_directory()",
            "PYTHON_DOTENV_DISABLED",
            "redact_browser_error_detail",
            "agent-browser returned non-JSON output",
            "agent-browser '{command_name}' failed",
            "browser_success_json_requires_successful_exit_status",
            "browser_json_output_requires_success_true_contract",
            "browser_command_rejects_empty_success_output",
            "cleanup_local_daemon",
            "cleanup_socket_dir_is_private",
            "metadata.permissions().mode() & 0o077",
            "browser_cleanup_ignores_non_owner_only_socket_directory",
            "browser_cleanup_ignores_symlinked_socket_directory",
            "browser_cleanup_removes_private_socket_directory",
            "command.arg(\"--session\").arg(session_name)",
        ] {
            #expect(browserCommand.contains(required), "Missing Rust browser-use command runner string: \(required)")
        }

        for required in [
            "EPISTEMOS_BROWSER_USE_AGENT_BROWSER",
            "EPISTEMOS_BROWSER_USE_VENDOR_ROOT",
            "EPISTEMOS_BROWSER_USE_CDP_URL",
            "epistemos_agent_browser.py",
            "resolve_agent_browser(",
            "require_executable_browser(",
            "cdp_url_from_env",
            "cdp_url_from_env_value",
            "validate_cdp_url",
            "must be valid UTF-8",
            "must point at localhost, 127.0.0.1, or [::1]",
            "must not include username or password credentials",
            "must not include a URL query",
            "must not include a URL fragment",
            "browser_cdp_url_env_accepts_only_loopback_urls",
            "not an executable file",
            "agent-browser CLI not found",
            "browser_use_agent_browser_override_wins_before_path_search",
            "browser_use_vendor_root_discovers_bundled_adapter",
            "browser_use_explicit_adapter_rejects_non_executable_without_fallback",
        ] {
            #expect(browserExecutable.contains(required), "Missing Rust browser-use discovery string: \(required)")
        }

        for required in [
            "optional_bool_field",
            "optional_string_field",
            "normalize_ref",
            "truncate_snapshot",
            "SNAPSHOT_CHAR_CAP",
            "ref cannot be empty",
            "browser_input_normalizes_refs_and_truncates_snapshots",
        ] {
            #expect(browserInput.contains(required), "Missing browser input policy string: \(required)")
        }

        for required in [
            "MAX_BROWSER_IMAGES",
            "MAX_BROWSER_IMAGE_TEXT_CHARS",
            "MAX_BROWSER_CONSOLE_ITEMS",
            "MAX_BROWSER_CONSOLE_TEXT_CHARS",
            "normalize_image_results",
            "normalize_snapshot_refs",
            "normalize_console_items",
            "bound_console_value",
            "sanitize_url_for_output",
            "browser_get_images_normalizes_and_bounds_page_controlled_results",
            "browser_snapshot_refs_are_bounded",
            "browser_console_output_bounds_page_controlled_values",
            "browser_url_output_drops_credentials_query_and_fragment",
        ] {
            #expect(browserOutput.contains(required), "Missing browser output policy string: \(required)")
        }

        for required in [
            "DirBuilderExt",
            "create_private_browser_dir(",
            "permissions.set_mode(0o700)",
            "reject_browser_dir_symlink",
            "private browser directory",
            "must not be a symlink",
            "validate_private_browser_dir_owner",
            "MetadataExt",
            "libc::geteuid",
            "must be owned by the current user",
            "browser_private_directories_are_owner_only",
            "browser_private_directories_reject_symlink_targets",
        ] {
            #expect(browserPrivate.contains(required), "Missing browser private-dir policy string: \(required)")
        }

        for required in [
            "redact_browser_error_detail",
            "redact_url_token",
            "contains_secret_assignment",
            "redacts_following_auth_value",
            "access_token",
            "x-api-key",
            "client_secret",
            "id_token",
            "auth_code",
            "opaqueBearerValue",
            "compact-bearer",
            "browser_error_redaction_covers_secret_assignment_variants",
        ] {
            #expect(browserRedaction.contains(required), "Missing browser redaction policy string: \(required)")
        }

        for required in [
            "AGENT_BROWSER_SCREENSHOT_DIR",
            "next_screenshot_path",
            "screenshot_directory",
            "create_private_browser_dir(",
            "/tmp/epistemos-browser-screenshots",
            "path_resolves_inside",
            "extract_screenshot_path",
            "normalize_screenshot_path_token",
            "MAX_SCREENSHOT_PATH_CHARS",
            "cleanup_screenshot_file",
            "browser_vision_screenshot_paths_must_resolve_inside_private_directory",
            "browser_screenshot_extracts_quoted_or_punctuated_png_tokens",
            "browser_screenshot_cleanup_removes_file_without_requiring_existing_path",
        ] {
            #expect(browserScreenshot.contains(required), "Missing browser screenshot policy string: \(required)")
        }
        #expect(browserTool.contains("browser screenshot was not created in private screenshot directory"))
        #expect(!browserTool.contains("browser screenshot was not created at"))
        #expect(!browserTool.contains("resolved outside private screenshot directory at"))

        for required in [
            "browser_navigate_schema",
            "browser_snapshot_schema",
            "browser_click_schema",
            "browser_type_schema",
            "browser_scroll_schema",
            "browser_back_schema",
            "browser_press_schema",
            "browser_close_schema",
            "browser_get_images_schema",
            "browser_vision_schema",
            "browser_console_schema",
            "\"allow_cloud_external_requests\"",
        ] {
            #expect(browserSchema.contains(required), "Missing browser schema string: \(required)")
        }

        let adapterIndex = try #require(browserExecutable.range(of: "browser_use_adapter")?.lowerBound)
        let pathFallbackIndex = try #require(browserExecutable.range(of: "for candidate in search_dirs")?.lowerBound)
        #expect(adapterIndex < pathFallbackIndex)
        #expect(!browserExecutable.contains("BROWSER_CDP_URL"))

        #expect(registry.contains("#[cfg(feature = \"pro-build\")]"))
        #expect(registry.contains("browser_navigate_schema()"))
    }
}
