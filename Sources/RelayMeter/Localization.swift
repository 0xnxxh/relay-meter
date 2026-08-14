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
    let cost: String
    let actualCost: String
    let estimatedCost: String
    let recent: String
    let trend: String
    let activity: String
    let activityDaily: String
    let activityWeekly: String
    let activityMonthly: String
    let activityCumulative: String
    let activityThisWeek: String
    let activityThisMonth: String
    let activityThisYear: String
    let activityLast7Days: String
    let activityLast30Days: String
    let activityLastYear: String
    let activityCustom: String
    let activityFrom: String
    let activityTo: String
    let activityLess: String
    let activityMore: String
    let activityRangeInvalid: String
    let activityRangeTooLong: String
    let activityViewDetails: String
    let activityRequests: String
    let activityTokens: String
    let activityUnknown: String
    let activityPartial: String
    let activityUnavailable: String
    let activityDataExportDisabled: String
    let apply: String
    let cancel: String
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
        cost: "花费", actualCost: "实际花费", estimatedCost: "预估花费",
        recent: "最近 15 分钟", trend: "趋势", activity: "用量活动",
        activityDaily: "每日", activityWeekly: "每周", activityMonthly: "每月", activityCumulative: "累计",
        activityThisWeek: "本周", activityThisMonth: "本月", activityThisYear: "日历年",
        activityLast7Days: "过去 7 天", activityLast30Days: "过去 30 天", activityLastYear: "滚动一年",
        activityCustom: "自定义...", activityFrom: "开始", activityTo: "结束", activityLess: "少", activityMore: "多",
        activityRangeInvalid: "开始日期不能晚于结束日期。", activityRangeTooLong: "自定义范围最多为 366 天。",
        activityViewDetails: "查看全年", activityRequests: "请求", activityTokens: "Token",
        activityUnknown: "未知", activityPartial: "部分数据", activityUnavailable: "活动数据不可用",
        activityDataExportDisabled: "new-api 未启用数据统计",
        apply: "应用", cancel: "取消", range: "时间范围", rangeToday: "今天",
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
        cache: "Cache", latency: "Latency", cost: "Spend", actualCost: "Actual spend", estimatedCost: "Estimated spend",
        recent: "Last 15m", trend: "Trend", activity: "Usage Activity",
        activityDaily: "Daily", activityWeekly: "Weekly", activityMonthly: "Monthly", activityCumulative: "Cumulative",
        activityThisWeek: "This Week", activityThisMonth: "This Month", activityThisYear: "Calendar Year",
        activityLast7Days: "Last 7 Days", activityLast30Days: "Last 30 Days", activityLastYear: "Rolling Year",
        activityCustom: "Custom...", activityFrom: "From", activityTo: "To", activityLess: "Less", activityMore: "More",
        activityRangeInvalid: "The start date must not be later than the end date.", activityRangeTooLong: "Custom ranges are limited to 366 days.",
        activityViewDetails: "View Year", activityRequests: "Requests", activityTokens: "Tokens",
        activityUnknown: "Unknown", activityPartial: "Partial data", activityUnavailable: "Activity data unavailable",
        activityDataExportDisabled: "new-api data export is disabled",
        apply: "Apply", cancel: "Cancel", range: "Range",
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

    func activityPeriodLabel(_ period: UsageActivityPeriod) -> String {
        switch period {
        case .today: rangeToday
        case .thisWeek: activityThisWeek
        case .thisMonth: activityThisMonth
        case .thisYear: activityThisYear
        case .last7Days: activityLast7Days
        case .last30Days: activityLast30Days
        case .lastYear: activityLastYear
        case .custom: activityCustom
        }
    }

    func activityGranularityLabel(_ granularity: UsageActivityGranularity) -> String {
        switch granularity {
        case .daily: activityDaily
        case .weekly: activityWeekly
        case .monthly: activityMonthly
        case .cumulative: activityCumulative
        }
    }
}

struct SettingsTextBundle {
    let windowTitle: String
    let title: String
    let subtitle: String
    let displaySection: String
    let language: String
    let menuBarTitle: String
    let launchAtLogin: String
    let approvalRequired: String
    let cardsSection: String
    let cancel: String
    let save: String
    let enabled: String
    let show: String
    let hide: String
    let addAdapter: String
    let delete: String
    let adaptersHint: String
    let metricRequests: String
    let metricTokens: String
    let metricFailures: String
    let metricSuccessRate: String
    let metricLatency: String
    let metricCache: String
    let metricRecent: String
    let metricCost: String
    let itemTraffic: String
    let itemSuccessRate: String
    let itemTokens: String
    let itemCache: String
    let itemLatency: String
    let itemRecent: String
    let itemTrend: String
    let itemActivity: String
    let itemTopModel: String
    let itemTopApiKey: String
    let itemRefreshedAt: String

    static func forLanguage(_ language: AppLanguage) -> SettingsTextBundle {
        language == .chinese ? chinese : english
    }

    func languageLabel(_ language: AppLanguage) -> String {
        switch language {
        case .english: "English"
        case .chinese: "简体中文"
        }
    }

    func metricLabel(_ metric: DisplayMetric) -> String {
        switch metric {
        case .requests: metricRequests
        case .tokens: metricTokens
        case .failures: metricFailures
        case .successRate: metricSuccessRate
        case .latency: metricLatency
        case .cache: metricCache
        case .recent: metricRecent
        case .cost: metricCost
        }
    }

    func itemLabel(_ item: DisplayItem) -> String {
        switch item {
        case .traffic: itemTraffic
        case .successRate: itemSuccessRate
        case .tokens: itemTokens
        case .cache: itemCache
        case .latency: itemLatency
        case .recent: itemRecent
        case .trend: itemTrend
        case .activity: itemActivity
        case .topModel: itemTopModel
        case .topApiKey: itemTopApiKey
        case .refreshedAt: itemRefreshedAt
        }
    }

    private static let chinese = SettingsTextBundle(
        windowTitle: "Relay Meter 设置",
        title: "设置",
        subtitle: "分别配置 adapter、菜单栏显示和监控卡片。",
        displaySection: "显示",
        language: "语言",
        menuBarTitle: "菜单栏默认显示",
        launchAtLogin: "登录时启动",
        approvalRequired: "需要授权",
        cardsSection: "卡片",
        cancel: "取消",
        save: "保存",
        enabled: "启用",
        show: "显示",
        hide: "隐藏",
        addAdapter: "添加 Adapter",
        delete: "删除",
        adaptersHint: "启用的 adapter 会并发刷新；单个 adapter 失败不会阻止其他 adapter 展示。",
        metricRequests: "请求数 + 成功率",
        metricTokens: "总 Token",
        metricFailures: "失败数",
        metricSuccessRate: "成功率",
        metricLatency: "平均延迟",
        metricCache: "缓存 Token",
        metricRecent: "最近 15 分钟活跃",
        metricCost: "花费",
        itemTraffic: "流量",
        itemSuccessRate: "成功率",
        itemTokens: "Token",
        itemCache: "缓存",
        itemLatency: "延迟",
        itemRecent: "最近 15 分钟",
        itemTrend: "趋势曲线图",
        itemActivity: "用量热力图",
        itemTopModel: "Top 模型",
        itemTopApiKey: "Top API Key",
        itemRefreshedAt: "最后更新时间"
    )

    private static let english = SettingsTextBundle(
        windowTitle: "Relay Meter Settings",
        title: "Settings",
        subtitle: "Configure adapters, menu bar display, and monitoring cards.",
        displaySection: "Display",
        language: "Language",
        menuBarTitle: "Menu Bar Title",
        launchAtLogin: "Launch at Login",
        approvalRequired: "Approval Required",
        cardsSection: "Cards",
        cancel: "Cancel",
        save: "Save",
        enabled: "Enabled",
        show: "Show",
        hide: "Hide",
        addAdapter: "Add Adapter",
        delete: "Delete",
        adaptersHint: "Enabled adapters refresh in parallel; one failed adapter does not block the others.",
        metricRequests: "Requests + success rate",
        metricTokens: "Total tokens",
        metricFailures: "Failures",
        metricSuccessRate: "Success rate",
        metricLatency: "Average latency",
        metricCache: "Cache tokens",
        metricRecent: "Last 15m activity",
        metricCost: "Spend",
        itemTraffic: "Traffic",
        itemSuccessRate: "Success rate",
        itemTokens: "Tokens",
        itemCache: "Cache",
        itemLatency: "Latency",
        itemRecent: "Last 15m",
        itemTrend: "Trend chart",
        itemActivity: "Usage heatmap",
        itemTopModel: "Top model",
        itemTopApiKey: "Top API key",
        itemRefreshedAt: "Last updated"
    )
}
