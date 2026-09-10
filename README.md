<div align="center">

# GLM Usage HUD

**macOS 菜单栏里的智谱 GLM Coding Plan 用量仪表**

圆环进度一目了然，5 小时窗口 / 每周额度尽在掌握

![menubar](docs/menubar.png)

原生 Swift · 零第三方依赖 · 无需完整 Xcode · Key 只存本机 Keychain

</div>

---

## 为什么需要它

GLM Coding Plan 采用「每 5 小时限额 + 每周限额」机制，额度用尽只能干等重置。写代码正嗨时突然 429，往往才发现窗口早已见底。GLM Usage HUD 把两个额度的消耗节奏钉在菜单栏——抬眼即知还剩多少余量、这一波烧得有多快，不用再去翻控制台网页。

## 功能一览

| 顶栏元素 | 说明 |
|---------|------|
| `◎ 圆环` | 5 小时窗口已用%，从 12 点方向顺时针填充 |
| `45% · 47%` | 等宽数字：5 小时已用% · 本周已用%，不抖动 |

点击顶栏项，下拉查看更多：

- **5 小时窗口**：已用数值（如 `12,600 / 28,000`）与重置时刻（`今天 19:22`）
- **本周额度**：已用数值与重置日期（`9月15日 (周二)`）
- 套餐档位（Lite / Pro / Max）、数据更新时间
- **立即刷新**（⌘R）、**配置 Key…**、**开机自启** 开关、退出

其他特性：

- ⏱ 每 15 分钟自动刷新，合盖唤醒后立即补拉一次
- 🔐 API Key 仅存本机 Keychain，不落盘、不进日志、只发往智谱官方域名
- ✅ 配置时「保存并测试」即时验证连通性并预览当前用量
- ⚠️ 断网 / Key 失效 / 接口异常时顶栏显示 ⚠️ 并给出原因，恢复后自愈
- 🌓 圆环为模板渲染，自动适配浅色 / 深色外观

## 环境要求

- macOS 13 及以上
- 一个智谱 GLM Coding Plan 订阅（Lite / Pro / Max 均可），以及 [open.bigmodel.cn](https://open.bigmodel.cn) 控制台创建的 API Key

## 安装

### 方式一：下载安装包（推荐）

1. 从 [Releases](../../releases) 下载最新 zip，解压得到 `GLM Usage HUD.app`
2. 拖入「应用程序」文件夹后打开
3. 首次打开若提示「无法验证开发者」：这是无开发者证书签名的正常现象，执行一次
   ```bash
   xattr -cr ~/Applications/GLM\ Usage\ HUD.app
   ```
   再重新打开即可
4. 首次读取 Keychain 可能弹授权框，点「始终允许」

### 方式二：源码构建

只需 Xcode Command Line Tools（无需完整 Xcode）：

```bash
git clone https://github.com/XuJyu/glm-usage-hud.git
cd glm-usage-hud
./build.sh        # 编译 + 组装 .app + 签名 + 安装到 ~/Applications
open ~/Applications/GLM\ Usage\ HUD.app
```

## 快速上手

1. 首次启动，顶栏显示 **`未配置`**
2. 点击它 → **配置 Key…**，粘贴你的 API Key
3. 点 **保存并测试**——看到 `✅ 连接成功：5小时已用 xx% · 本周已用 xx%` 即大功告成
4. 想开机常驻？下拉菜单勾选 **开机自启**

## 工作原理

调用智谱开放平台网页控制台同源的用量接口：

```
GET https://open.bigmodel.cn/api/monitor/usage/quota/limit
Authorization: Bearer <你的 API Key>
```

响应中按语义识别两类限额（`unit=3,number=5` → 5 小时窗口；`unit=6,number=1` → 周额度），两个百分比直接取服务端 `percentage` 字段（已用口径），与控制台显示一致。解析与展示分层解耦，核心逻辑有单元测试锁定。

> ⚠️ **免责声明**：该接口为平台内部接口（非官方公开 API），智谱调整接口时本工具可能失效——届时顶栏会显示 ⚠️ 与错误原因，不会静默给出错误数据。本工具仅为个人用量监控用途，与智谱官方无关。

## 常见问题

**Q：重新构建/更新后，读取 Keychain 又弹授权框？**
应用使用 ad-hoc 签名，每次构建的身份指纹不同，点一次「始终允许」即可。

**Q：顶栏项不见了？**
菜单栏空间不足（刘海屏常见）时会被系统隐藏，按住 ⌘ 拖动调整位置。

**Q：顶栏显示 ⚠️？**
下拉查看具体原因：网络断开、Key 失效（401）或接口返回异常。多数情况恢复网络后 ≤15 分钟自愈，或点「立即重试」。

**Q：支持国际版 Z.AI 吗？**
暂未适配，当前仅支持国内版 open.bigmodel.cn。

## 已知限制

- 无单实例保护：重复启动会出现两个顶栏项（退出一个即可）
- 周额度百分比取服务端取整值，与自行计算的余量可能相差 1 个百分点

## 开发

```bash
swift build    # 构建
swift test     # 单元测试（解析 / 边界 / 确定性时间格式）
```

代码结构：

```
Sources/GLMUsageCore      # 纯逻辑库：模型 / API 客户端 / 格式化（全 Sendable 值类型）
Sources/glm-usage-hud     # AppKit UI：状态机 / 顶栏与菜单 / 配置窗口（全 @MainActor）
Tests/GLMUsageCoreTests   # 单元测试
build.sh                  # 构建 + 组装 .app + ad-hoc 签名 + 安装
```

## License

[MIT](LICENSE)
