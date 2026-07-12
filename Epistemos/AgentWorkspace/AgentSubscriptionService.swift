#if EPISTEMOS_LEGACY_RECEIPT_PROXY
import Foundation
import Observation
import OSLog
import StoreKit

// Plan 1-MAS §5 — StoreKit 2 subscription gate for Surface B.
// Purchase → JWS-signed Transaction → EpistemosProxyClient exchanges it for
// a short-lived proxy token (server verifies via the App Store Server API;
// deprecated verifyReceipt is never used). Purchases carry an
// appAccountToken so the proxy can rate-limit per account. The free lane
// (Surface A) has no gate at all (§0.5).

@MainActor
@Observable
final class AgentSubscriptionService {
    enum Entitlement: Equatable {
        case unknown
        case notSubscribed
        case subscribed(expires: Date?)
    }

    static let shared = AgentSubscriptionService()

    /// App Store Connect product (owner-configured; override for local
    /// testing via EPISTEMOS_AGENT_PRODUCT_ID).
    static var productID: String {
        ProcessInfo.processInfo.environment["EPISTEMOS_AGENT_PRODUCT_ID"]
            ?? "app.epistemos.agent.monthly"
    }

    private static let log = Logger(subsystem: "com.epistemos", category: "AgentSubscription")
    private static let accountTokenKey = "epistemos.proxy.appAccountToken"

    private(set) var entitlement: Entitlement = .unknown
    private(set) var product: Product?
    private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refresh() }
    }

    // App-lifetime singleton: the Transaction.updates listener lives as long
    // as the process; no deinit path.

    /// Stable per-install account token (kept in Keychain) binding purchases
    /// to proxy rate limits (§5).
    static func appAccountToken() -> UUID {
        if let stored = Keychain.load(for: accountTokenKey), let uuid = UUID(uuidString: stored) {
            return uuid
        }
        let fresh = UUID()
        _ = Keychain.save(fresh.uuidString, for: accountTokenKey)
        return fresh
    }

    // MARK: - Store operations

    func refresh() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            Self.log.warning("Product load failed: \(error.localizedDescription, privacy: .public)")
        }
        await refreshEntitlement()
    }

    func purchase() async {
        lastError = nil
        guard let product else {
            lastError = "Subscription product isn't available right now."
            return
        }
        do {
            let result = try await product.purchase(
                options: [.appAccountToken(Self.appAccountToken())]
            )
            switch result {
            case .success(let verification):
                await handle(verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// The signed JWS for the current entitlement — what the proxy verifies.
    func currentEntitlementJWS() async -> String? {
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  transaction.productID == Self.productID else { continue }
            return entitlement.jwsRepresentation
        }
        return nil
    }

    /// Ensures a live proxy session, exchanging the entitlement JWS when the
    /// token is absent or near expiry (refresh below ~20% TTL).
    func ensureProxySession() async throws -> EpistemosProxySession {
        if let session = EpistemosProxyClient.shared.currentSession(), !session.needsRefresh {
            return session
        }
        guard let jws = await currentEntitlementJWS() else {
            throw EpistemosProxyError.receiptRejected(status: 401, body: "no active subscription")
        }
        return try await EpistemosProxyClient.shared.exchangeReceipt(
            jws: jws,
            appAccountToken: Self.appAccountToken()
        )
    }

    // MARK: - Internals

    private func handle(_ verification: VerificationResult<Transaction>) async {
        switch verification {
        case .verified(let transaction):
            if transaction.productID == Self.productID {
                await transaction.finish()
                await refreshEntitlement()
            }
        case .unverified(_, let error):
            Self.log.warning("Unverified transaction: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshEntitlement() async {
        var found: Entitlement = .notSubscribed
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  transaction.productID == Self.productID else { continue }
            found = .subscribed(expires: transaction.expirationDate)
            break
        }
        entitlement = found
        if case .notSubscribed = found {
            EpistemosProxyClient.shared.clearSession()
        }
    }
}
#endif // EPISTEMOS_LEGACY_RECEIPT_PROXY — parked; no MAS cloud subscription product is active
