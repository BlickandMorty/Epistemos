import Testing
@testable import Epistemos

@Suite("LLMError")
struct LLMErrorTests {

    // MARK: - isTransient

    @Test("429 is transient")
    func transient429() {
        let err = LLMError.apiError(statusCode: 429, body: "rate limited")
        #expect(err.isTransient)
    }

    @Test("529 is transient")
    func transient529() {
        let err = LLMError.apiError(statusCode: 529, body: "overloaded")
        #expect(err.isTransient)
    }

    @Test("503 is transient")
    func transient503() {
        let err = LLMError.apiError(statusCode: 503, body: "unavailable")
        #expect(err.isTransient)
    }

    @Test("502 is transient")
    func transient502() {
        let err = LLMError.apiError(statusCode: 502, body: "bad gateway")
        #expect(err.isTransient)
    }

    @Test("401 is not transient")
    func notTransient401() {
        let err = LLMError.apiError(statusCode: 401, body: "unauthorized")
        #expect(!err.isTransient)
    }

    @Test("400 is not transient")
    func notTransient400() {
        let err = LLMError.apiError(statusCode: 400, body: "bad request")
        #expect(!err.isTransient)
    }

    @Test("200 is not transient")
    func notTransient200() {
        let err = LLMError.apiError(statusCode: 200, body: "ok")
        #expect(!err.isTransient)
    }

    // MARK: - isAuthError

    @Test("401 is auth error")
    func auth401() {
        let err = LLMError.apiError(statusCode: 401, body: "")
        #expect(err.isAuthError)
    }

    @Test("403 is auth error")
    func auth403() {
        let err = LLMError.apiError(statusCode: 403, body: "")
        #expect(err.isAuthError)
    }

    @Test("400 is NOT auth error")
    func notAuth400() {
        let err = LLMError.apiError(statusCode: 400, body: "bad request")
        #expect(!err.isAuthError)
    }

    @Test("429 is NOT auth error")
    func notAuth429() {
        let err = LLMError.apiError(statusCode: 429, body: "")
        #expect(!err.isAuthError)
    }

    // MARK: - errorDescription

    @Test("each status code has a unique error description")
    func errorDescriptions() {
        let codes = [429, 529, 503, 502, 401, 403, 400, 500]
        var descriptions = Set<String>()
        for code in codes {
            let err = LLMError.apiError(statusCode: code, body: "test")
            let desc = err.errorDescription ?? ""
            #expect(!desc.isEmpty, "code \(code) should have a description")
            descriptions.insert(desc)
        }
        #expect(descriptions.count == codes.count, "each code should produce a unique description")
    }

    @Test("400 includes body detail")
    func errorDescription400() {
        let err = LLMError.apiError(statusCode: 400, body: "max_tokens too large")
        let desc = err.errorDescription ?? ""
        #expect(desc.contains("400"))
        #expect(desc.contains("max_tokens"))
    }

    @Test("400 with empty body produces clean message")
    func errorDescription400Empty() {
        let err = LLMError.apiError(statusCode: 400, body: "")
        let desc = err.errorDescription ?? ""
        #expect(desc.contains("400"))
    }

    @Test("unknown status code has generic message")
    func errorDescriptionUnknown() {
        let err = LLMError.apiError(statusCode: 418, body: "teapot")
        let desc = err.errorDescription ?? ""
        #expect(desc.contains("418"))
    }

    // MARK: - ConnectionTestResult

    @Test("ConnectionTestResult stores fields")
    func connectionTestResult() {
        let success = ConnectionTestResult(success: true, message: "OK")
        #expect(success.success)
        #expect(success.message == "OK")

        let failure = ConnectionTestResult(success: false, message: "Failed")
        #expect(!failure.success)
    }
}
