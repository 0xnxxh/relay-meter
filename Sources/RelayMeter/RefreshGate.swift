struct RefreshGate {
    private(set) var isRefreshing = false

    mutating func begin() -> Bool {
        guard !isRefreshing else { return false }
        isRefreshing = true
        return true
    }

    mutating func finish() {
        isRefreshing = false
    }

    mutating func reset() {
        isRefreshing = false
    }
}
