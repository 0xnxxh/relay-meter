struct TextBundle {
    let today: String
    let live: String
    let traffic: String
    let requests: String
    let failures: String
    let successRate: String
    let tokens: String
    let cache: String
    let latency: String
    let recent: String
    let trend: String
    let range: String
    let rangeToday: String
    let range7d: String
    let range30d: String
    let rangeAll: String
    let topModel: String
    let topApiKey: String
    let updated: String
    let settings: String
    let checkForUpdates: String
    let openMonitoring: String
    let refresh: String
    let platform: String
    let adapters: String
    let adapterName: String
    let allAdapters: String
    let baseURL: String
    let managementKey: String
    let newApiUserID: String
    let refreshIntervalSeconds: String
    let quit: String
    let total: String
    let input: String
    let output: String
    let reasoning: String
    let last15m: String
    let tokenUnit: String
    let cacheUnit: String
    let avg: String
    let ttft: String
    let healthGood: String
    let healthIdle: String
    let healthWarn: String
    let healthBad: String
    let loading: String
    let error: String

    static func forLanguage(_ language: AppLanguage) -> TextBundle {
        language == .chinese ? chinese : english
    }

    private static let chinese = TextBundle(
        today: "今日", live: "实时", traffic: "流量", requests: "请求", failures: "失败",
        successRate: "成功率", tokens: "Token", cache: "缓存", latency: "延迟",
        recent: "最近 15 分钟", trend: "趋势", range: "时间范围", rangeToday: "今天",
        range7d: "7 天", range30d: "30 天", rangeAll: "全部",
        topModel: "Top 模型", topApiKey: "Top API Key",
        updated: "更新", settings: "设置", checkForUpdates: "检查更新...",
        openMonitoring: "打开监控页",
        refresh: "立即刷新",
        platform: "主 Adapter",
        adapters: "Adapters",
        adapterName: "名称",
        allAdapters: "总览",
        baseURL: "服务地址", managementKey: "访问密钥", newApiUserID: "new-api 用户 ID", refreshIntervalSeconds: "刷新间隔（秒）",
        quit: "退出",
        total: "总量", input: "输入", output: "输出", reasoning: "推理",
        last15m: "15 分钟", tokenUnit: "tok", cacheUnit: "缓存", avg: "平均",
        ttft: "TTFT", healthGood: "健康", healthIdle: "空闲", healthWarn: "关注",
        healthBad: "异常", loading: "刷新中", error: "错误"
    )

    private static let english = TextBundle(
        today: "Today", live: "Live", traffic: "Traffic", requests: "requests",
        failures: "failures", successRate: "Success Rate", tokens: "Tokens",
        cache: "Cache", latency: "Latency", recent: "Last 15m", trend: "Trend", range: "Range",
        rangeToday: "Today", range7d: "7d", range30d: "30d", rangeAll: "All",
        topModel: "Top Model",
        topApiKey: "Top API Key", updated: "Updated", settings: "Settings",
        checkForUpdates: "Check for Updates...",
        openMonitoring: "Open Monitoring Page", refresh: "Refresh Now",
        platform: "Primary Adapter",
        adapters: "Adapters",
        adapterName: "Name",
        allAdapters: "All",
        baseURL: "Base URL", managementKey: "Access Key", newApiUserID: "new-api User ID",
        refreshIntervalSeconds: "Refresh Interval (seconds)", quit: "Quit", total: "total", input: "in",
        output: "out", reasoning: "reasoning", last15m: "15m", tokenUnit: "tok",
        cacheUnit: "cache", avg: "avg", ttft: "TTFT", healthGood: "Healthy",
        healthIdle: "Idle", healthWarn: "Watch", healthBad: "Errors",
        loading: "...", error: "Error"
    )
}
