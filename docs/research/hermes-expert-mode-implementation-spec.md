# Hermes Expert Mode — Implementation Spec

## Overview
This specification details the end-to-end integration of "Hermes Expert Mode" into the Epistemos application as a managed, local Python subprocess exposing an OpenAI-compatible HTTP/SSE and MCP architecture.

## Non-Goals
* No Hermes-in-Swift FFI port (avoids prior failed architecture)
* No complete rewrite of the native Epistemos agent
* No cloud-hosted fallback for Hermes
* No fine-tuning or training loops
* No MAS (Mac App Store) support at v1.1 for Expert Mode
* No multi-agent swarms

## Runtime Architecture (RQ-1, RQ-2)
Hermes will be executed via a bundled Python runtime via `astral-sh/python-build-standalone`. The build process produces a universal macOS binary utilizing CPython 3.12 embedded inside the Epistemos DD (Direct Distribution) bundle. The process strictly utilizes `--options runtime`, `com.apple.security.cs.allow-jit`, and `com.apple.security.cs.disable-library-validation` entitlements, intentionally avoiding the vulnerable executable memory entitlements.

## Subprocess Handshake and Protocol (RQ-4, RQ-5)
The communication channel relies on local HTTP + SSE on `127.0.0.1` utilizing a random high port parsed dynamically from stderr. Both HTTP and MCP sockets enforce static IP binding and 32-byte CSPRNG token validation to defend against DNS-rebinding attacks. 

## Tooling and Bridging via MCP (RQ-6, RQ-7)
No manual JSON-schema-to-OpenAI translation is built. Epistemos makes `MCPBridge.swift` reachable from the Python subprocess via an internal HTTP MCP server. Hermes, possessing native MCP client connectivity, discovers Epistemos-native tools dynamically at boot via the `/v1/epistemos/bootstrap` connection. Approval-gated tools trigger the `EpistemosApprovalShim`, temporarily suspending subprocess tasks and proxying prompts back to native SwiftUI modals.
