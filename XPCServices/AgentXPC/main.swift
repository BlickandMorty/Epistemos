import Foundation

let delegate = AgentServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
