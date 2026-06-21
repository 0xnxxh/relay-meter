# Relay Meter

Native macOS menu bar monitor for Claude/OpenAI relay dashboards.

Relay Meter shows traffic, success rate, token/cache usage, latency, recent activity, top model, and top API key directly in the macOS menu bar. The interface supports English and Simplified Chinese.

## English

### Install

1. Download the latest `Relay-Meter-v*.dmg` from GitHub Releases.
2. Open the DMG and drag `Relay Meter.app` to `/Applications`.
3. Remove macOS quarantine before the first launch:

```sh
xattr -cr "/Applications/Relay Meter.app"
```

4. Open `Relay Meter.app`. It appears in the menu bar and does not show a Dock icon.

This `xattr -cr` step is required because the app is distributed without Apple Developer ID notarization.

### Configure

On first launch, Relay Meter creates its config file automatically at `~/.config/relay-meter/config.json`.

Open `Settings` from the menu bar and set:

- `adapters`: an array of relay backends to monitor at the same time. Each item has `id`, `name`, `enabled`, `platform`, `baseURL`, `managementKey`, optional `authHeaderName`, optional `newApiUserID`, and optional `monitoringPath`.
- `platform`: primary adapter mirror field. `Settings` can add or delete adapter entries, including multiple entries with the same platform, and mirrors the first enabled adapter into these top-level fields.
- `baseURL`: primary relay server, for example `https://relay.example.com`.
- `managementKey`: the access key for the primary adapter.
- `authHeaderName`: optional override for the primary adapter auth header. Defaults are platform-specific.
- `newApiUserID`: required only for `newApi`, because new-api admin routes require the `New-Api-User` header.
- `language`: `en` for English or `zh-Hans` for Simplified Chinese.
- `refreshIntervalSeconds`: refresh interval; the minimum is 10 seconds.
- `titleMetric`: menu bar title metric, such as `requests`, `tokens`, `successRate`, or `latency`.
- `timeRange`: `today`, `7d`, `30d`, or `all`.

Saving in `Settings` applies the new config immediately. Keep `~/.config/relay-meter/config.json` private because it contains an access key.

When multiple adapters are enabled, the menu bar title shows the aggregate total. The menu body has source tabs: `All` first, then one tab per adapter. Switching tabs changes the cards, rankings, and trend chart between the aggregate view and a single adapter. If one adapter fails, the others still render and the failed adapter appears as an error on the aggregate tab.

For `sub2api`, the default `managementKey` field should be the admin API key configured in sub2api. Relay Meter sends it as `x-api-key: <managementKey>`. sub2api also accepts an admin JWT as `Authorization: Bearer <jwt-token>`, but Relay Meter's Settings window uses the admin API key path by default.

### Backend Support

Relay Meter has dedicated adapters for these projects:

| Platform | Project | Auth | Data path |
| --- | --- | --- | --- |
| `cliproxyapiPro` | [ssfun/CLIProxyAPI-Pro](https://github.com/ssfun/CLIProxyAPI-Pro) | `Authorization: Bearer <managementKey>` | `GET /v0/management/usage/aggregates` |
| `sub2api` | [Wei-Shaw/sub2api](https://github.com/Wei-Shaw/sub2api) | `x-api-key: <managementKey>` by default, or admin JWT with `Authorization: Bearer ...` if overridden | `GET /api/v1/admin/dashboard/stats`, `trend`, `models`, and `api-keys-trend` |
| `newApi` | [QuantumNous/new-api](https://github.com/QuantumNous/new-api) | `Authorization: <access-token>` plus `New-Api-User: <newApiUserID>` | `GET /api/log/` with local aggregation |

The current app was originally built around [ssfun/CLIProxyAPI-Pro](https://github.com/ssfun/CLIProxyAPI-Pro), so that link is intentionally kept explicit. `sub2api` and `new-api` expose different routes and response schemas, so they are integrated through separate adapters rather than by changing only `baseURL`.

`newApi` support aggregates the latest fetched log page locally. If your instance has more than 200 records in the selected range, the top lists and trend chart reflect the newest 200 matching log rows.

### Use

- Open `Settings` from the menu bar to edit config.
- Use the range tabs to switch between today, 7 days, 30 days, and all retained logs.
- Use `Open Monitoring Page` on `All` to open every enabled adapter's monitoring page, or on an adapter tab to open that adapter's page.
- Use `Check for Updates...` to check GitHub Releases for a newer version.

### Logs

Runtime logs are written to:

```text
~/Library/Logs/relay-meter/relay-meter.log
```

The log does not write the access key.

## 中文

### 安装

1. 从 GitHub Releases 下载最新的 `Relay-Meter-v*.dmg`。
2. 打开 DMG，把 `Relay Meter.app` 拖到 `/Applications`。
3. 首次启动前移除 macOS quarantine 标记：

```sh
xattr -cr "/Applications/Relay Meter.app"
```

4. 打开 `Relay Meter.app`。它会显示在 macOS 菜单栏，不显示 Dock 图标。

因为当前应用没有 Apple Developer ID 公证，所以必须执行上面的 `xattr -cr`。

### 配置

首次启动时，Relay Meter 会自动创建配置文件：`~/.config/relay-meter/config.json`。

在菜单栏中打开 `设置`，填写：

- `adapters`：需要同时监控的中转后端数组。每项包含 `id`、`name`、`enabled`、`platform`、`baseURL`、`managementKey`、可选 `authHeaderName`、可选 `newApiUserID`、可选 `monitoringPath`。
- `platform`：主 adapter 的镜像字段。`设置` 窗口可以添加或删除 adapter，包括多个同平台实例，并把第一个启用的 adapter 同步到这些顶层字段。
- `baseURL`：主中转服务地址，例如 `https://relay.example.com`。
- `managementKey`：主 adapter 的访问密钥。
- `authHeaderName`：主 adapter 的可选鉴权头覆盖项。默认值按平台选择。
- `newApiUserID`：仅 `newApi` 需要，因为 new-api admin 路由要求 `New-Api-User` 请求头。
- `language`：`en` 为英文，`zh-Hans` 为简体中文。
- `refreshIntervalSeconds`：刷新间隔，最小 10 秒。
- `titleMetric`：菜单栏标题指标，例如 `requests`、`tokens`、`successRate` 或 `latency`。
- `timeRange`：`today`、`7d`、`30d` 或 `all`。

在 `设置` 中保存后，新配置会立即生效。请保护好 `~/.config/relay-meter/config.json`，里面包含访问密钥。

启用多个 adapter 时，菜单栏标题显示聚合总量；菜单展开后有来源标签：第一个是 `总览`，后面每个 adapter 一个标签。切换标签会在聚合视图和单个 adapter 之间切换卡片、排行和趋势图。单个 adapter 失败不会阻止其他 adapter 展示，失败项会显示在总览标签下。

`sub2api` 的 `managementKey` 默认应填写 sub2api 后台配置的 Admin API Key。Relay Meter 会用 `x-api-key: <managementKey>` 发送。sub2api 也支持管理员 JWT：`Authorization: Bearer <jwt-token>`，但设置页默认走 Admin API Key 方式。

### 后端支持

Relay Meter 已为这些项目提供独立 adapter：

| 平台 | 项目 | 鉴权 | 数据接口 |
| --- | --- | --- | --- |
| `cliproxyapiPro` | [ssfun/CLIProxyAPI-Pro](https://github.com/ssfun/CLIProxyAPI-Pro) | `Authorization: Bearer <managementKey>` | `GET /v0/management/usage/aggregates` |
| `sub2api` | [Wei-Shaw/sub2api](https://github.com/Wei-Shaw/sub2api) | 默认 `x-api-key: <managementKey>`；如覆盖为 `Authorization`，可使用管理员 JWT `Bearer ...` | `GET /api/v1/admin/dashboard/stats`、`trend`、`models`、`api-keys-trend` |
| `newApi` | [QuantumNous/new-api](https://github.com/QuantumNous/new-api) | `Authorization: <access-token>` 加 `New-Api-User: <newApiUserID>` | `GET /api/log/`，应用侧本地聚合 |

当前应用最初围绕 [ssfun/CLIProxyAPI-Pro](https://github.com/ssfun/CLIProxyAPI-Pro) 开发，因此 README 明确保留该项目链接。`sub2api` 和 `new-api` 的路由、鉴权和响应结构不同，所以不能只改 `baseURL`，必须走各自 adapter。

`newApi` 支持会对最近获取到的日志页做本地聚合。如果所选范围内超过 200 条记录，排行榜和趋势图反映最新 200 条匹配日志。

### 使用

- 在菜单栏中打开 `设置` 修改配置。
- 使用时间范围标签切换今天、7 天、30 天和全部日志。
- 在 `总览` 使用 `打开监控页` 会打开所有启用 adapter 的监控页面；在单个 adapter 标签使用时只打开该 adapter 的监控页面。
- 使用 `检查更新...` 从 GitHub Releases 检查新版本。

### 日志

运行日志写入：

```text
~/Library/Logs/relay-meter/relay-meter.log
```

日志不会写入访问密钥。
