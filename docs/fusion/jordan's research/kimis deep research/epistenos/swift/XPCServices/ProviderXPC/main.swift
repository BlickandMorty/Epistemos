//  main.swift
//  ProviderXPC — Sandboxed Helper Entry Point
//
//  Stateless cloud-provider router. Same discipline as AgentXPC:
//  reads from the App Group arena, verifies capability grants, and
//  forwards to curated provider adapters.
//

import Foundation

// MARK: - Listener Delegate

class ProviderServiceDelegate: NSObject, NSXPCListenerDelegate {

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        let interface = NSXPCInterface(with: ProviderServiceProtocol.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = ProviderService()

        newConnection.invalidationHandler = {
            // Stateless — no cleanup required.
        }
        newConnection.interruptionHandler = {
            // Stateless — no cleanup required.
        }

        newConnection.resume()
        return true
    }
}

// MARK: - Launch

let delegate = ProviderServiceDelegate()
let listener = NSXPCListener(serviceName: "com.epistenos.providerxpc")
listener.delegate = delegate
listener.resume()

RunLoop.main.run()
