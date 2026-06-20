# CPA Menubar

Native macOS menu bar monitor for CLIProxyAPI-Pro usage.

CPA Menubar shows traffic, success rate, token/cache usage, latency, recent activity, top model, and top API key directly in the macOS menu bar. The interface supports English and Simplified Chinese.

## English

### Install

1. Download the latest `CPA-Menubar-v*.dmg` from GitHub Releases.
2. Open the DMG and drag `CPA Menubar.app` to `/Applications`.
3. Remove macOS quarantine before the first launch:

```sh
xattr -cr "/Applications/CPA Menubar.app"
```

4. Open `CPA Menubar.app`. It appears in the menu bar and does not show a Dock icon.

This `xattr -cr` step is required because the app is distributed without Apple Developer ID notarization.

### Configure

On first launch, CPA Menubar creates its config file automatically at `~/.config/cpa-menubar/config.json`.

Open `Settings` from the menu bar and set:

- `baseURL`: your CLIProxyAPI-Pro server, for example `https://cpa.example.com`.
- `managementKey`: the management key used by the CLIProxyAPI-Pro management page.
- `language`: `en` for English or `zh-Hans` for Simplified Chinese.
- `refreshIntervalSeconds`: refresh interval; the minimum is 10 seconds.
- `titleMetric`: menu bar title metric, such as `requests`, `tokens`, `successRate`, or `latency`.
- `timeRange`: `today`, `7d`, `30d`, or `all`.

Saving in `Settings` applies the new config immediately. Keep `~/.config/cpa-menubar/config.json` private because it contains your management key.

### Use

- Open `Settings` from the menu bar to edit config.
- Use the range tabs to switch between today, 7 days, 30 days, and all retained logs.
- Use `Open Monitoring Page` to open the full CLIProxyAPI-Pro monitoring page.
- Use `Check for Updates...` to check GitHub Releases for a newer version.

### Logs

Runtime logs are written to:

```text
~/Library/Logs/cpa-menubar/cpa-menubar.log
```

The log does not write the management key.

## 中文

### 安装

1. 从 GitHub Releases 下载最新的 `CPA-Menubar-v*.dmg`。
2. 打开 DMG，把 `CPA Menubar.app` 拖到 `/Applications`。
3. 首次启动前移除 macOS quarantine 标记：

```sh
xattr -cr "/Applications/CPA Menubar.app"
```

4. 打开 `CPA Menubar.app`。它会显示在 macOS 菜单栏，不显示 Dock 图标。

因为当前应用没有 Apple Developer ID 公证，所以必须执行上面的 `xattr -cr`。

### 配置

首次启动时，CPA Menubar 会自动创建配置文件：`~/.config/cpa-menubar/config.json`。

在菜单栏中打开 `设置`，填写：

- `baseURL`：CLIProxyAPI-Pro 服务地址，例如 `https://cpa.example.com`。
- `managementKey`：CLIProxyAPI-Pro 管理页面使用的管理密钥。
- `language`：`en` 为英文，`zh-Hans` 为简体中文。
- `refreshIntervalSeconds`：刷新间隔，最小 10 秒。
- `titleMetric`：菜单栏标题指标，例如 `requests`、`tokens`、`successRate` 或 `latency`。
- `timeRange`：`today`、`7d`、`30d` 或 `all`。

在 `设置` 中保存后，新配置会立即生效。请保护好 `~/.config/cpa-menubar/config.json`，里面包含管理密钥。

### 使用

- 在菜单栏中打开 `设置` 修改配置。
- 使用时间范围标签切换今天、7 天、30 天和全部日志。
- 使用 `打开监控页` 打开完整 CLIProxyAPI-Pro 监控页面。
- 使用 `检查更新...` 从 GitHub Releases 检查新版本。

### 日志

运行日志写入：

```text
~/Library/Logs/cpa-menubar/cpa-menubar.log
```

日志不会写入管理密钥。
