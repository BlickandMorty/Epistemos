//  main.swift
//  AgentXPC — Sandboxed Helper Entry Point
//
//  Stateless, non-authoritative. Reads requests from the App Group arena,
//  verifies capability grants, and executes via AgentRuntimeBridge.
//  The system may launch this helper on demand and terminate it when idle.
//

import Foundation

// MARK: - Listener Delegate

class AgentServiceDelegate: NSObject, NSXPCListenerDelegate {

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        let interface = NSXPCInterface(with: AgentServiceProtocol.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = AgentService()

        newConnection.invalidationHandler = {
            // No state to clean up — the helper is stateless.
        }
        newConnection.interruptionHandler = {
            // No state to clean up — the helper is stateless.
        }

        newConnection.resume()
        return true
    }
}

// MARK: - Launch

let delegate = AgentServiceDelegate()
let listener = NSXPCListener(serviceName: "com.epistenos.agentxpc")
listener.delegate = delegate
listener.resume()

// Block the service thread on the main run loop.
// The helper stays alive as long as `listener` has an outstanding resume.
RunLoop.main.run()
