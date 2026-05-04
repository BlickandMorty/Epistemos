import Foundation

let delegate = ProviderServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
