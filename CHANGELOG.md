# StudySync Changelog

## v1.0.2 Overall

v1.0.2 是 v1.0.1 在 App Store 公开发布后的第一个**公开热修复 + 功能补齐**版本。本版集中做了三件事：

1. **新增完整的「出行追踪」子系统**（航班 / 高铁 / 轮渡等 7 类交通方式，7 种导入路径含 Wallet / 条码 / PDF / 航班号查询等）—— 与日历事件视觉差异化，自动状态刷新 + 多档提醒预设
2. **修了三个 v1.0.1 上线后用户实际反映的致命 bug** —— 重启 / 崩溃后数据清零、中国大陆登录卡死、Focus Timer 切 tab 自动暂停。前两个是 P0 数据 / 可用性问题，第三个是 P1 体验问题
3. **建立了一套 Apple 上架预检自动化** —— 5 个静态检查脚本 + git pre-commit hook，覆盖本地化齐全度、Info.plist 权限文案、ATS 合规、review-killer 关键词、必备 plist key。这一套是从过往两次 Apple Guideline 4 拒审里学来的教训

新增 iCloud 同步首次启动引导（一次性 sheet，对**所有用户**包括受 v1.0.1 数据丢失影响的老用户都会显示一次），让 sync 这个之前藏在 Settings 深处的功能被实际用起来。Localization 在写新代码的同时实时跑预检脚本，13 条新中文 key 一次补齐 en / ja / ko / zh-Hant 共 88 条翻译。Build 号 = 2（CFBundleShortVersionString = 1.0.2 / CFBundleVersion = 2）。

---

## v1.0.1 Overall (Internal Iteration)

v1.0.1 是 StudySync 在 App Store 首次通过审核的公开版本。在私有迭代的基础上，修复了 Apple Guideline 4 拒审的权限文案本地化问题，补齐韩文/日文全量翻译，新增出行追踪、早鸟终身 Pro、删除账户等一揽子功能与合规加固。

---

### v1.0.2 (2)

**🚨 P0 数据丢失修复 — SwiftData 同进程双 container 元数据腐蚀**

v1.0.1 上线后用户反映 app 重启或崩溃后**所有的 todo / 倒计时 / 学习目标都被清零**。根因：

- 主 app 的 `StudySyncApp.swift` 用 **13 个 entity** 的 schema 打开 `AppGroup/StudySync.store`
- 同一进程里：
  - `DeadlineBackgroundChecker`（iOS 后台唤醒主进程时触发）调 `SharedModelContainer.create()` 用**只有 4 个 entity** 的 schema 打开**同一个** store
  - `AddCountdownIntent` / `CheckCountdownIntent` / `TodayOverviewIntent`（App Intent 从 Spotlight / Shortcuts 触发时也跑在主进程）—— 同样
- 两个 ModelContainer 在同一进程里指向同一个 SQLite store + schema 不一致 = CoreData 文档明确说的 **undefined behavior**，会腐蚀 store metadata
- 腐蚀后下次启动 `try ModelContainer(for: schema)` 抛错 → 落到 `try!` in-memory 兜底 → 用户看到空数据 → 加新数据存到 in-memory → 重启又丢

修复手段（5 个文件）：

- **新增 `StudySync/Services/AppContainer.swift`** —— 进程唯一的 ModelContainer 持有者（`@MainActor` final class，`register()` 一次写入，`requireContainer()` throwing 取出）。文件顶上 80 行注释解释这个 bug 的来龙去脉，挡住未来再有人随手 `ModelContainer(...)`
- **`StudySyncApp.swift`** —— `init` 末尾调 `AppContainer.shared.register(container)` 注册唯一实例；**删除了 silent `try!` in-memory 兜底**。新策略：CloudKit 失败 → 试 local-only → 还失败 → sleep 0.5s 重试一次 → 再失败 `fatalError` 让 iOS 重启 app（远好于让用户在 in-memory 状态下加数据然后丢）
- **`DeadlineBackgroundChecker.swift`** —— 改用 `AppContainer.shared.container`，移除 `SharedModelContainer.create()` 调用
- **3 个 AppIntent** —— `AppContainer.shared.container ?? SharedModelContainer.create()`，主进程跑时用主 container，独立进程兜底用旧路径

效果：磁盘数据没真删，只是 schema 不一致读不出来。装上 hotfix 后绝大多数受影响用户**重启就能恢复历史数据**。

---

**🚨 P1 中国大陆登录卡死修复 — Firebase + GFW 超时**

中国用户反映点了登录后**无限转圈最终强退 app**。根因：Firebase Auth 走 `firebaseauth.googleapis.com`，Firestore 走 `firestore.googleapis.com`，**都被 GFW 屏蔽**。`Auth.auth().signIn(...)` 在 TCP 层等约 75 秒才超时，UI 显示 spinner 期间用户已经放弃了。

- **新增 `StudySync/Utilities/AsyncTimeout.swift`** —— `withTimeout(seconds:)` 工具，用 Swift `TaskGroup` 实现，超时抛 `NetworkTimeoutError`（"网络请求超时，请检查网络后重试"）
- **包了 5 个 Firebase 调用：**
  - `AuthService.handleAppleSignIn` → `signIn(with:)` —— 12s
  - `AuthService.signInWithEmail` → `signIn(withEmail:)` —— 12s
  - `AuthService.signUpWithEmail` → `createUser` + `commitChanges` —— 12s + 8s
  - `AuthService.sendPasswordReset` —— 10s
  - `FirestoreService.getUserProfile`（登录链路上的 profile load）—— 10s

中国用户最多等 **12 秒**就看到错误提示，而不是 75s 死循环。措辞用中性"网络超时"——避开 Apple 不喜欢的 "VPN" / "GFW" 暗示。

---

**🐞 Focus Timer 切 tab 自动暂停修复**

用户反映**专注开始后切到其他 tab 再切回来，倒计时停了**，需要手动点暂停 + 恢复才能重新跑。

根因：`FocusTimerView.onDisappear { timer?.invalidate() }`。SwiftUI TabView 切换会触发 onDisappear → timer 被 invalidate → 但 `timerState` 还是 `.running`（onDisappear 没改状态）。切回来 onAppear 只跑动画，**没有重启 timer**，UI 显示运行中但实际不前进。

- **`FocusTimerView.swift`** —— 删掉 `.onDisappear` 里的 timer cleanup，加 30 行注释解释为什么不能在这里清理。timer 改由：`pauseTimer` / `completeSession` / `giveUp` / `scenePhase → .background` 这四个**真正的**生命周期点负责

顺手做了**全量审计**：扫了项目里所有 11 个 `.onDisappear` 块，确认其他 10 个要么是动画 timer（celebration overlay）要么有正确配对的 `.onAppear`。只有 FocusTimerView 是真 bug。

---

**☁️ iCloud 同步首次启动引导**

之前 iCloud 同步开关藏在 Settings 深处，多数用户根本不知道存在。

- **新增 `StudySync/Views/Onboarding/iCloudPromptView.swift`** —— 一次性 sheet，3 个卖点（多设备同步 / 防丢失 / 端到端加密），带"启用 / 暂不开启"两个按钮
- 用 `@AppStorage("hasShownICloudPrompt")` 控制只显示一次
- **专门用独立的标志而不是复用 `hasCompletedOnboarding`**：受 v1.0.1 数据丢失影响的老用户已经过了 onboarding，那批人最需要知道有 iCloud sync 这个保险。独立标志保证所有用户都会看到一次

钩在 `MainTabView.task {}` 里延迟 1.5s（splash 结束后）+ 0.8s（避开生日动画冲突）→ 弹 sheet。点启用 → `iCloudSyncManager.shared.isEnabled = true`，按钮变"完成"+ 图标弹 `checkmark.icloud.fill`，底部显示"下次打开 App 后同步将自动激活"。

---

**🛡️ Apple 上架预检自动化套件（5 个脚本 + git pre-commit hook）**

历史上这个 app 被 Apple 拒审过两次，都是 Guideline 4 因为字符串本地化不全。这次建了一套静态检查防线，目标：**任何会导致 Apple 拒审的低级错误都不应该靠人肉 review**。

- **`scripts/check_localizations.py`** —— 扫所有 `String(localized:)` 和带插值的 `Text("...\(...)")`，对照 `Localizable.xcstrings` 验证 4 个目标 locale（en / ja / ko / zh-Hant）都有 `state: translated`。处理了 嵌套括号 `\(arr.filter { $0 }.count)`、引号嵌套 `Text("$\(x, specifier: "%.2f")")`、`%` literal 转义（仅当含 format specifier 时双写）、`%@` ↔ `%lld` 互探等所有边角情况
- **`scripts/check_infoplist_localizations.py`** —— `NSCameraUsageDescription` / `NSCalendarsFullAccessUsageDescription` 等 8 个 `NS*UsageDescription` + `CFBundleName` + 3D-touch shortcut titles 在 `InfoPlist.xcstrings` 里都齐 4 语言
- **`scripts/check_review_killers.py`** —— 用户可见字符串里的 `TestFlight` / `测试版` / `沙盒` / `localhost` / `Beta build` / `Lorem ipsum` / `TODO` —— 这些是 Guideline 2.1 / 2.3 拒审热词。同时扫所有 xcstrings 翻译值（防 zh-Hans 干净但 ja 翻错混入）
- **`scripts/check_ats_compliance.py`** —— 每个 `http://` URL 的 host 在 `Info.plist` `NSExceptionDomains` 里都有对应 entry（含 `NSIncludesSubdomains` 标志）
- **`scripts/check_required_keys.py`** —— `Info.plist` 含 `ITSAppUsesNonExemptEncryption`；`PrivacyInfo.xcprivacy` 含 4 个顶层 key（Tracking / TrackingDomains / CollectedDataTypes / AccessedAPITypes），且每个 `NSPrivacyAccessedAPIType` 必有 `NSPrivacyAccessedAPITypeReasons` 数组
- **`scripts/check_app_review.py`** —— umbrella 入口，串行跑 5 个子检查，最后打总结。`--quiet` flag 给 git hook 用（只在失败时输出详情）
- **`scripts/install-git-hooks.sh`** —— 一键装 pre-commit hook，只在 staged 文件含 `.swift` / `.xcstrings` / `.plist` / `.xcprivacy` 时触发

跑过一次回归测试：故意塞 `Text("TestFlight build · 测试版")` → 立刻被 review-killer 检查抓到 → 删掉 → 全绿 ✓。1097 个 localized key 全检查只用 < 1 秒。

---

**🌐 Localization 完整性补齐**

写新代码的同时实时跑 `check_localizations.py`：

- **航班查询 + 配额错误流程的 9 条 key** —— `数据来源`、`更多行程`、`未配置 %@ API 密钥 — 请先填入`、`本月共享 %@ 配额已用完...`、`网络请求失败 (%lld)：%@`、`配置我自己的 API Key`、`%@ API Key`（动态拼接 header）等
- **iCloud 引导的 13 条 key** —— `开启 iCloud 同步`、`多设备无缝同步`、`防止数据丢失`、`端到端加密`、`下次打开 App 后同步将自动激活...` 等
- **网络超时的 1 条 key** —— `网络请求超时，请检查网络后重试`

合计 22 个新 key × 4 个目标 locale = **88 条翻译一次性补齐**，状态全部 `translated`。预检脚本最终输出：`✓ all 1097 keys are translated for ['en', 'ja', 'ko', 'zh-Hant']`。

---

**🎯 AeroDataBox 接入 + 配额耗尽智能降级**

v1.0.1 时航班查询用 AviationStack（100 次/月免费 + 免费版只支持当日实时）。中国用户查未来航班直接 403 `function_access_restricted`。

- **新增 `Services/Travel/FlightLookupProvider.swift`** —— 抽象层：`FlightLookupResult` neutral DTO、`FlightLookupProvider` 协议（actor-based）、`FlightProviderRegistry`（UserDefaults 持久化的 provider 选择）、统一 `FlightLookupError`（含 `.quotaExceeded(provider:)` / `.missingAPIKey(provider:)` / `.apiError`）
- **新增 `Services/Travel/AeroDataBoxClient.swift`** —— RapidAPI 客户端，500 次/月免费，**支持未来 + 历史日期**。处理了 AeroDataBox 时间格式（`"2026-04-28 09:00Z"` 空格不是 T、`Z` vs offset 二选一）、~15 种 status 字符串归一化到 6 种 canonical
- **`AviationStackClient.swift` 重构** —— 改为实现 `FlightLookupProvider` 协议，错误类型统一到 `FlightLookupError`，`usage_limit_reached` / `rate_limit_reached` 自动归类为 `.quotaExceeded`
- **`Secrets.swift` 用 XOR 混淆嵌入 AeroDataBox key** —— 拆成 `aeroEncoded[]` + `aeroMask[]` 两个 50-byte 数组，运行时 `zip().map(^)` 解码。挡住 `strings(1)` 扒字符串和 GitHub 爬泄露 key 的扫描器（注：挡不住 LLDB / Hopper，真要安全只能上后端代理）
- **配额耗尽 UI** —— `FlightAPILookupView` 检测到 `.quotaExceeded` 时错误变橙色 + 多一个醒目按钮"配置我自己的 API Key"，引导用户注册自己的 RapidAPI 账号（每账号 500 次/月）
- **`FlightLookupView` 新增 segmented picker** 让用户在 AeroDataBox / AviationStack 之间切换，选择保存到 UserDefaults

新版默认用 AeroDataBox，老 AviationStack 作为可选方案保留。

---

**📅 Schedule 行程显示重构 — 不再置顶，按时间穿插到当天**

之前所有行程不分日期一律置顶在 Schedule 顶部一个独立 section，遮挡当天日历事件。

- **`CalendarFeedView.swift`** —— 删除顶部"行程"section；引入 `DayItem` enum（`.calendar(EKEvent)` / `.travel(TravelEvent)`），每天的列表合并日历事件 + 当天行程，按时间排序：完成的 deadline 沉底 → 全天事件顶 → 其他按 `startDate` / `departureInstant`
- **当天 badge 计数**包含日历事件 + 行程总数
- **超出 `calendarDayRange` 的远期行程**显示在所有日子下方的"更多行程"小 section（浅灰，不抢视线）—— 不至于 3 天 calendarDayRange 把 2 周后的航班完全藏起来

---

**✈️ TravelCardView 视觉精修**

中间连接线之前会因为机场名字长被挤偏。

- 端点列改为 `.frame(maxWidth: .infinity, alignment:)` 等宽 flex；中间列固定 108pt 宽 → 线和飞机图标永远居中
- 路线线条从 `ZStack { Rectangle + 居中 ✈️ }` 改为 `●──✈️──●`（端点小圆点 + 中间图标）
- 时间字号 20→22pt heavy rounded + `minimumScaleFactor(0.8)`
- 机场代码加 `.tracking(0.5)`
- 长机场名走 `.lineLimit(1) + .truncationMode(.tail)` 在正确一侧省略号截断

---

**👥 Acknowledgements 更新**

`AboutView.swift`：
- Yixuan Wei emoji `🌟` → `🧑🏻‍💼`
- 新增股东 Chuxiang Jin（emoji `🎻`）

---

**📦 Build 元数据**

- `MARKETING_VERSION` `1.0.2`，`CURRENT_PROJECT_VERSION` `2`
- 8 个 target × 2 个 config 一致

---

### v1.0.2 (1)

**出行系统：机票 / 高铁票 / 轮渡等一站式行程管理**

Schedule 新增「行程」类型，视觉上与普通日历事件明显区分（彩色渐变卡 + 横向路线可视化 + 交通方式图标），覆盖航班、高铁、动车、城际、火车、长途大巴、轮渡 7 种。

- **数据模型（6 个新文件）**
  - `TravelEvent` (`@Model`)：航班号 / 车次 / 起止站 / 终端登机口 / 座位 / PNR / 状态 / 延误分钟 / 提醒预设 / 导入来源 / Wallet Pass 标识 / 备注。起止时间以"本地 wall-clock 时间 + 时区 ID"存储，跨时区航班显示时不会因手机系统时区变化而错乱
  - `TravelSegment`：转机 / 中转段的值类型，以 JSON 编码到 `segmentsData`
  - `TravelKind`：7 种交通方式枚举，每种有独立的渐变色（飞机 sky→deep blue / 高铁 silver→red CRH 涂装 / 轮渡 teal→ocean 等）+ SF Symbol + 自动识别正则（航班 `[A-Z]{2,3}\d{1,4}` / 高铁 `[GDC]\d{1,5}` / 火车 `[KTZYL]\d{1,5}`）
  - `TravelStatus`：8 种状态（`scheduled` / `checkInOpen` / `boarding` / `enRoute` / `arrived` / `delayed` / `cancelled` / `completed`）+ 各自的强调色 + SF Symbol
  - `TravelReminderPreset`：7 种提醒方案，国际航班 T-24h/4h/3h/90m/30m 梯度、国内航班 T-24h/150m/2h/1h/25m、高铁 T-3h/1h/30m/10m 等
  - `TravelImportSource`：9 种导入来源枚举 + 是否支持刷新状态的标识

- **7 种导入方式全部实现**
  1. **Apple Wallet 登机牌**（`WalletTravelImporter`）—— `PKPassLibrary` 列出用户已加入 Wallet 的登机牌，读取 `passTypeIdentifier` / `organizationName` / `relevantDate` / `serialNumber` / `localizedValue(forFieldKey:)` 构造草稿。Apple 会自动刷新延误，无需我们轮询
  2. **航班号 + 日期查询**（`FlightAPIImporter` + `AviationStackClient`）—— 免费 100 次/月 API，`http://api.aviationstack.com/v1/flights?flight_iata=CA981&flight_date=...`。API Key 读取优先级：`UserDefaults["aviationstack.api_key"]` → 内置 `embeddedAPIKey` 常量 → 抛 `.missingAPIKey`。ATS 例外已加到 `Info.plist` 允许 `api.aviationstack.com` HTTP 访问
  3. **日历 .ics 自动识别**（`CalendarTravelImporter`）—— 扫描未来 90 天的 EventKit 事件，标题含航班 / 高铁 / 普通列车 designator 或位置 / 备注含机场 / 车站 / 航空等关键字的自动晋升为候选。已复用主 app 的 `NSCalendarsFullAccessUsageDescription`
  4. **PDF417 / QR 条码扫描**（`TravelBarcodeScanner` + `BarcodeTravelImporter`）—— 新建 AVFoundation 扫码器支持 `.pdf417` / `.qr` / `.aztec`，取景框自适应 iPad。PDF417 解析 IATA BCBP 标准格式（M1 版本头 + 姓名 + PNR + FROM/TO IATA + 承运 + 航班号 + 儒略日 + 座位）。QR 针对 12306 车票文本提取 G/D/C 开头的车次号
  5. **PDF 电子票解析**（`PDFTravelImporter`）—— `PDFKit` 提取全文，正则扫 designator + 机场 3 字母 IATA 代码 + HH:MM 时刻。英语 stopwords 过滤降低误匹配
  6. **文本粘贴 / Share 解析**（`ShareIntakeService` + `PasteImportView`）—— 正则提取航班号 / 车次 + 日期（`yyyy-MM-dd`、`M月d日`、`Jan 25, 2026` 三种格式）。支持 `studysync://travel?flight=CA981&date=2026-04-25` URL scheme，`DeepLinkRouter` 已接入
  7. **手动表单**（`ManualTravelFormView`）—— 自动识别车次前缀切换类型、时区选择器（常用 15 个区）、车站选择器配合 `RailStations` 数据库

- **高铁数据库**（`RailStations.swift`）—— 60+ 主要 HSR / 铁路枢纽，含中文名 / 英文名 / 3 字母代码 / 城市 / 时区。覆盖全国主要省会 + 一线二线城市主要站点。搜索支持中文 / 英文 / 代码 / 城市模糊匹配

- **实时航班状态**（`TravelStatusRefresher`）—— 后台刷新已加入的航班状态。策略：
  - 只刷 24 小时内出发的航班（节约 API 免费额度）
  - 单个事件 20 分钟内不重复刷新
  - 已到达 / 已取消 / 已完成的跳过
  - 更新 `statusRaw` / `delayMinutes` / 登机口 / 终端 / `lastStatusRefreshedAt`

- **提醒调度**（`TravelReminderScheduler`）—— 按预设生成本地通知，标识格式 `travel_<uuid>_<offsetSeconds>`，改动 / 删除时可精准取消 + 重建。所有触发时间基于真实 UTC 时刻（`departureInstant`）而不是 wall-clock，跨时区不会双触发或错过

- **UI（5 个新文件）**
  - `TravelCardView`：横向路线可视化 + 渐变背景 + 状态 pill + 60 秒一次的实时倒计时。iPad / iPhone 自适应
  - `TravelDetailView`：信息表格 + 提醒开关 + 状态刷新按钮 + 删除 + 来源溯源
  - `AddTravelView`：8 个导入方式选单（含手动、航班号查、高铁 / 火车、Wallet、日历、条码、PDF、粘贴文本）
  - `ManualTravelFormView`：表单 + 车站选择器 + 时区选择器
  - `FlightAPILookupView`：航班号查询 + 候选列表 + API Key 配置
  - `OtherImportViews` / `TravelBarcodeScanner`：Wallet / Calendar / Barcode / PDF / Paste 独立视图
  - `CalendarFeedView` 顶部新增「行程」区块，Schedule 底部 + 按钮改为菜单，区分添加日历事件 vs 添加行程

- **ATS + Info.plist**：允许 `api.aviationstack.com` 的 HTTP 请求（免费套餐限 HTTP）。不影响其他域的 HTTPS 强制

- **Widget 模型共享**：6 个 Travel 相关模型文件加入 widget target 成员例外，SwiftData schema 扩展包含 `TravelEvent`

- **Firestore**：暂未接入云端同步（行程是高度个人 + 短期数据，本地 SwiftData 充足；未来可做跨设备同步）

- **L10n**：新增 149 条翻译键 × 5 语言（zh-Hans / zh-Hant / en / ko / ja），含所有 UI 文案、状态标签、提醒梯度文案、导入方式标题

---

### v1.0.1 (14)

**多语言支持扩展：韩文 + 日文 + Info.plist 本地化 + 全面审核合规审计 + Delete Account + Pro 早鸟奖励 + 权益一致性 + 警告清理 + L10n 审计**

- **Pro 权益系统重构 — 早鸟终身 Pro + tag 一致性修复**：

  - **新增 `UserProfile.proLifetime: Bool` + `earlyBirdGrantedAt: Date?`**
    - 表示用户拥有终身 Pro 权益（早鸟奖励，或将来的一次性买断 IAP）
    - `isProActive(storeKitPurchased:)` 计算属性作为 UserProfile 层的单一真相：`proLifetime || StoreKit 订阅 || (proRewardExpiresAt > now)`

  - **`ProEntitlementService` — reconciler 模式协调 `roles` 数组**
    - 把 Firestore 里的 `roles: [String]` 从"独立字段"改造为**派生字段**：`roles.contains("pro")` 必须始终等于真实 Pro 状态
    - 每次 `loadProfile` / 购买成功 / 获得专注奖励 / StoreKit transaction 变化时自动运行 reconcile：
      - 若应有 "pro" 但没有 → 加上
      - 若不应有 "pro" 但有（例如 3 个月奖励到期）→ 移除
    - **修复历史 bug**：以前用户奖励过期后 Firestore 的 `roles` 永远不会自动清理，好友页持续看到 stale Pro tag。现在每次 app 启动都会检查

  - **早鸟终身 Pro 自动发放（时间锁定 + 服务端防篡改）**
    - **注册截止（`earlyBirdRegistrationCutoff`）**：2026-04-25 00:00 多伦多时间（= 04:00 UTC）。`createdAt` 严格早于此值的用户合格
    - **发放激活时间（`earlyBirdGrantActiveFrom`）**：2026-04-27 00:00 多伦多时间。在此之前即使合格也不会写入 `proLifetime`，给我们 Apr 25–26 两天窗口推送更新 + 观察上架
    - 发放动作：合格用户下次打开 App 且系统时间 ≥ 激活时间时，reconciler 写入 `proLifetime=true + earlyBirdGrantedAt=now`，并在 `roles` 里加上 `"pro"` 和 `"early_bird"` 两个 tag
    - 幂等：`earlyBirdGrantedAt` 非空后不会再发放；删除账户重建新 `createdAt` ≥ cutoff 也不合格

  - **Firestore 安全规则防篡改（`firestore.rules`）**：
    - `createdAt` 创建后**永久不可修改**（`createdAtImmutable()`）
    - `proLifetime` 只允许 `false → true` 单向转换，且必须满足：`resource.data.createdAt < earlyBirdRegistrationCutoffMs` AND `request.time >= earlyBirdGrantActiveFromMs`。`true → false` 永远被拒绝（用户一旦获得不会失去）
    - `earlyBirdGrantedAt` 只能首次赋值且必须等于 `request.time`（服务端时间），防止客户端伪造过去时间
    - 新账户（create）不能"出生即终身 Pro"：`proLifetime` 和 `earlyBirdGrantedAt` 必须是默认未设置状态
    - 截止和发放时间以**毫秒常量硬编码在规则里**（`earlyBirdRegistrationCutoffMs = 1777089600000`, `earlyBirdGrantActiveFromMs = 1777262400000`），与客户端常量保持一致但服务端自成一套真相
    - 已通过 `firebase deploy --only firestore:rules --dry-run` 验证语法

  - **好友 Pro tag 实时同步**：`FirestoreService.propagateRolesToFriends(uid:roles:)` 在 role 变动时把最新 `roles` 数组写入每个好友缓存的 `users/{friendUid}/friends/{uid}` 文档，好友页不再需要手动刷新就能看到 tag 变化

  - **`StoreManager.isPro` 补齐终身 Pro 判断**
    - 原本只考虑 StoreKit 订阅 + 3 个月奖励，早鸟用户虽然 Firestore 上有 `"pro"` role 但本地 `isPro` 仍然 false，导致付费功能不解锁。现在加入 `hasLifetimeGrant`（读 `AuthService.userProfile?.proLifetime`），彻底对齐客户端门控与服务端 role

  - **`PaywallView` 智能区分三种 Pro 状态**
    - 当 `isPro == true` 时，不再显示购买按钮，改为展示庆祝卡片：
      - `proLifetime` → "🎁 终身 Pro — 感谢你的早期支持"
      - `isPurchasedPro` → "通过 App Store 购买激活"
      - `proRewardExpiresAt` → "专注挑战奖励 · 有效期至 2026年7月15日"
    - 避免早鸟用户点进 paywall 还看到"升级到 Pro"的尴尬

  - **新增 L10n：4 条 Pro 状态文案 × 5 语言翻译**

- **Apple 审核合规全面审计 & 修复（8 类隐患）**：

  - **CRITICAL 修复：`NSCalendarsFullAccessUsageDescription` 缺失**
    - `CalendarManager.swift:40` 调用 `requestFullAccessToEvents()` 但 `Info.plist` 既没有 `NSCalendarsFullAccessUsageDescription` 也没有旧版 `NSCalendarsUsageDescription` — iOS 17+ 触发日历授权时**会直接 crash**。补齐两个 key + 对应 `InfoPlist.xcstrings` 5 语言翻译

  - **CRITICAL 修复：`fatalError` 崩溃路径**
    - `AuthService.swift:227` 当 `SecRandomCopyBytes` 失败时 `fatalError`。改为用 `UUID` 作为 CSPRNG 的 graceful fallback（UUID v4 内部走同样的 secure random pool，对于一次性 nonce 足够安全），避免极端情况下 crash

  - **HIGH 修复：生产 paywall 出现 "TestFlight 测试版" 字样**
    - `PaywallView.swift` 的 sandbox banner 虽然 gated 在 receipt 检测后，但字面含 "TestFlight / 测试版" — 审核员也在 sandbox 环境下测试会看到。Guideline 2.3 风险。完整移除 banner + 清理关联 L10n 常量 + xcstrings 孤儿条目

  - **CRITICAL 修复：本地通知内容硬编码中文**
    - `ReviewReminderService.swift` 考试复习提醒的 title/body 直接拼中文。改用 `String(localized:)` 本地化，补齐 4 条 5 语言翻译（7 天前/3 天前/1 天前提醒 + "复习提醒 📖" 标题）

  - **CRITICAL 修复：Watch App 本地化缺失**
    - `StudySyncWatch Watch App/Localizable.xcstrings` 原本只有 en + zh-Hant，现补齐 ko + ja 共 8 个键

  - **CRITICAL 修复：Widget 全部硬编码中文**
    - 7 个 widget 文件共 20 处 `Text("中文")` / Widget 配置 `configurationDisplayName` / `IntentDescription` 等。新建 `StudySyncWidget/Localizable.xcstrings` 补齐 20 个键 × 5 语言。修复 "时差%lldh"（无空格）与 "时差 %lldh"（有空格）符号冲突

  - **CRITICAL 修复：App Intents / Siri Shortcuts 硬编码**
    - `StudySyncShortcuts.swift` / `CheckCountdownIntent.swift` / `TodayOverviewIntent.swift` / `AddCountdownIntent.swift` 的 `LocalizedStringResource` / `IntentDescription` / `@Parameter(title:)` / `Summary` / `.result(dialog:)` 等。大部分 key 已通过主 `Localizable.xcstrings` 自动映射；新增 6 个格式串 key（intent dialog 插值生成的 `%@ %@：%lld %@` 等）。另修复 `TodayOverviewIntent` 用字符串拼接而非插值的问题，确保可提取本地化

  - **CRITICAL 实现：Delete Account 流程（Apple Guideline 5.1.1 强制要求）**
    - `FirestoreService.deleteAllUserData(uid:)`：按 collection 批量删除 `users/{uid}` 下全部 subcollection（friends / friendRequests / sentFriendRequests / sharedDues / availability / focusStats / checkIns / studyGoals / countdowns / todos / projectInvites / notifications），删除主 user doc，删除 studyRoom 存在感，从 groupFocus 房间中移除自己，同时**反向清理好友通讯录**（从别人的 friends 子集合移除自己）。使用 WriteBatch（500 上限）分块提交，每个清理步骤相互隔离避免单点失败阻塞
    - `AuthService.deleteAccount()`：清 FCM token → 停监听 → Firestore 清理 → `Auth.user.delete()`。处理 `requiresRecentLogin` 错误码，`DeleteAccountError` 实现 `LocalizedError` 协议
    - `SocialHubView` 新增「永久删除账户」按钮（trash.fill / #B00020），二次确认 alert + 全屏 ProgressView 遮罩 + 错误 alert。翻译 8 个新 L10n 常量 × 5 语言

  - **MEDIUM 修复：iPad 布局问题**
    - `QRScannerView` 取景框原本硬编码 260×260，iPad Air M3（审核设备）上过小。改用 `GeometryReader` 自适应为 `min(屏幕短边 × 0.6, 420)`，四角指示器偏移量同步缩放

  - **MEDIUM 修复：AI Monitor 灰色地带披露（Guideline 5.2.3 风险缓解）**
    - `AddAIAccountView` 新增免责声明："使用你自己的账户凭证获取你自己的用量数据，数据仅在本设备使用。此功能与 AI 服务提供方无官方合作，若对方调整接口可能暂时失效。" 明确用户自己的账户、本地数据、非官方合作三点，降低 5.2.3 拒审概率

- **Apple 审核合规 — 已验证合规（本次审计通过的项）**：
  - `PrivacyInfo.xcprivacy` 与实际代码完全匹配（UserDefaults CA92.1 声明 / EmailAddress / Name / PreciseLocation 都已正确声明）
  - Background modes (`fetch` / `remote-notification`) 都有对应实现，无冗余
  - 无 IDFA 使用，无 `NSUserTrackingUsageDescription` 需要
  - `ITSAppUsesNonExemptEncryption=false` 正确（仅 TLS + Apple Sign-In nonce）
  - StoreKit 2 实现合规，restore purchase 功能齐全
  - Apple Sign-In + Email 登录，无第三方 SSO 强制要求 Apple Sign-In 的问题

---

**v1.0.1 (14) 前置工作：**

**多语言支持扩展：韩文 + 日文 + Info.plist 本地化 + 警告清理 + L10n 审计**

- **修复 App Store 审核问题（Guideline 4 - Design）**：
  - 新增 `InfoPlist.xcstrings` 本地化 `Info.plist` 中的权限请求文案（`NSCameraUsageDescription` / `NSLocationWhenInUseUsageDescription` / `NSPhotoLibraryAddUsageDescription`）到 5 种语言。之前权限请求文案硬编码为中文，在英/韩/日系统上会显示中文，Apple 审核（iPad Air M3 + 日文环境）以此为由驳回
  - Home Screen Quick Actions（长按 App 图标的快捷操作）标题补齐 ko / ja 翻译，移除原先中英双语并列的 `UIApplicationShortcutItemSubtitle`。现在三个入口「添加倒计时 / 今日日程 / 学习目标」会跟随系统语言显示

- **新增韩文 (ko) 和日文 (ja) 全量翻译**：
  - `project.pbxproj` 的 `knownRegions` 添加 `ko` 和 `ja`
  - `Localizable.xcstrings` 为全部 **1014 个字符串键**补齐 ko + ja 翻译（共 2028 条新翻译）
  - 翻译风格：日文用敬体（です・ます），韩文用해요体，专业名词音译（番茄钟→ポモドーロ/뽀모도로），App 名称 StudySync 保持英文
  - 覆盖所有模块：倒计时、专注、团队项目、学习目标、社交、AI 监控、徽章、通知文案等


- **Swift 6 警告清理（6 项）**：
  - `AvailabilityService.cleanupPastDays` 移除未使用的 `todayString`
  - `FirestoreService` 两处 `runTransaction` 返回值显式 `_ =` 丢弃
  - `FocusTimerView.TimerState` 提升为顶层 `nonisolated enum FocusTimerState: Equatable`，解决项目 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 下 Timer 回调内比较触发的 actor 隔离警告（Swift 6 模式下会升级为错误）

- **L10n 审计修复（7 处用户可见字符串）**：
  - 学习分析「本周报告」卡片：`本周学习 / 完成 / 最长连续打卡 / 提升|减少 %` 4 行文字本地化
  - 分享周报文本（`shareText`）走 L10n，社交分享时跟随语言切换
  - 团队项目 `ProjectDueEventCard` / `ProjectDueRow` 受派人数 `\(count)人` 改用 `L10n.projectMemberCount`
  - `Localizable.xcstrings` 新增 7 条 en / zh-Hant 翻译

---

### v1.0.1 (13)

**大版本：专注生态系统 + 多人联动 + 个人空间**

本次更新围绕「专注」核心体验进行大规模扩展，新增 8 大功能模块 + Cloud Functions 推送补全。

**🎯 专注模式增强（3 项）**

- **学习分析 (StudyAnalyticsView)**：5 大维度可视化 — 7 日专注柱状图、累计趋势线、时段热力分布、科目分布饼图、个人记录卡。基于 Swift Charts (`BarMark` / `LineMark` / `AreaMark`)
- **番茄休息系统**：`TimerState` 扩展为 5 态（`.idle` / `.running` / `.paused` / `.breakTime` / `.breakPaused`）。每完成一个番茄钟自动进入休息（短休 5 分钟 / 长休 15 分钟，每 4 个番茄钟触发长休）。休息期间环形进度条切换为绿色/青色渐变
- **数据导出 (DataExportView)**：支持导出专注记录、打卡记录、成绩数据为 CSV，通过 `ShareLink` 分享

**👥 多人联动（3 项）**

- **虚拟自习室 (StudyRoomView)**：专注时自动加入全局自习室，Firestore 实时监听在线成员。显示头像、专注科目、进度条、已用/总时长。离开专注自动退出
- **组队专注 (GroupFocusView)**：3 模式 UI（房间列表 → 等候室 → 同步倒计时）。房主创建房间选择时长/emoji，≥2 人后可开始。所有成员同步倒计时，完成后专注时间 ×1.5 作为组队 bonus 写入 `FocusSession.foregroundSeconds`，累积到月度挑战活动
- **拍一拍送达确认**：Cloud Functions 新增 `onNudgeSent` + `onRingNudgeSent` 两个触发器。对方手机成功收到拍一拍/响铃后，自动回推一条「已送达 ✅」通知给发送者。`sendToTokens` 返回 `successCount` 用于判断送达

**🏠 个人空间（2 项）**

- **虚拟学习空间 (StudySpaceView)**：专注解锁桌面装饰品，14 件物品分 4 阶（1h 📓 → 1000h 👑）。解锁时弹出动画 overlay。桌面可视化展示已解锁物品、累计时长、下一解锁目标。SwiftData `StudySpaceItem` 模型 + 静态 `DeskItem` 目录
- **书桌装饰展示到 Profile**：`UserProfile` / `FriendInfo` 新增 `showcaseDecorations: [String]`（最多 5 个）。ProfileView 新增「展示书桌」Section，amber 主题选择器。UserProfileDetailView header card 显示「我的书桌」。SocialHubView 好友卡片同步展示

**📚 待办 & 日程增强（2 项）**

- **待办课程关联**：`TodoItem` 新增 `courseName` 字段。AddTodoView / EditTodoView 新增课程选择器（从 GradeCourse 查询 + 自定义输入）。TodoListView 新增课程筛选栏 + 行内课程标签
- **考试复习计划**：`CountdownEvent` 新增 `isExam` / `reviewRemindersEnabled` 字段。新增 `ReviewReminderService`，考前 7/3/1 天通过 `UNCalendarNotificationTrigger` 推送本地提醒。EventDetailView 显示复习计划卡片

**🔧 Firestore & 基础设施**

- `FirestoreService` 新增 9 个方法：studyRoom（join/leave/listen）、groupFocus（create/join/start/updateStatus/delete/listen/fetchActive）
- `firestore.rules` 新增 `studyRoom/{uid}` 和 `groupFocus/{roomId}` 读写规则
- `StudySpaceItem.self` 注册到 SwiftData Schema
- `PushNotificationType` 新增 `.nudgeReceived` / `.nudgeDelivered` / `.ringNudgeReceived` / `.ringNudgeDelivered` 4 个 case，social tab 路由已覆盖

**新增 L10n**

- 学习分析 11 条、自习室 5 条、组队专注 20 条、学习空间 9 条、书桌展示 5 条、数据导出 5 条、考试复习 4 条

---

### v1.0.1 (12)

**改进：AI Monitor 优化 + 集合 ETA 修复 + 仅 iPhone 构建**

**AI Monitor 优化（9 项）**

- 并行抓取：`fetchAllUsage` 从逐个串行改为 `TaskGroup` 并行抓取，多账号刷新速度大幅提升
- 用量趋势图：新增 `AIUsageTrendView`，Swift Charts 绘制 24h/7d 用量折线 + 渐变面积 + 阈值警示线，Claude 额外显示 7d 窗口虚线
- 趋势数据模型：新增 SwiftData `AIUsageSnapshot`（accountId / utilization1 / utilization2 / timestamp），4 分钟节流写入，7 天自动清理
- 利用率归一化修复：`normalizeUtilization` 边界条件 `<= 1.0` → `< 1.0`，新增 `isPercentField` 参数避免已经是百分比的字段被误乘 100
- 数据过期提示：`AIUsageCardView` 当 `lastFetchedAt` 超过 30 分钟时显示橙色感叹号
- 智能排序：AI 账号列表优先显示未认证账号（引导设置），其次按峰值利用率降序
- 刷新防抖：`AIAccountDetailView` 刷新间隔最短 10 秒，避免重复请求
- 高峰时区选择：Claude 账号详情页新增时区选择器（Toronto / New York / LA / Chicago / London / Paris / Tokyo / Sydney），影响峰值时段判断
- 内存泄漏修复：`AIWebScraper` 超时机制从 `DispatchQueue.main.asyncAfter` 改为可取消 `Task.sleep`，`finish()` 时取消 `timeoutTask`
- Debug 日志默认关闭

**集合 (Meetup) ETA 修复（4 项）**

1. **[严重] 离开详情页后 ETA 停止上传**：`MeetupDetailView.onDisappear` 调用了 `stopTracking()`，导致用户一离开详情页就停止位置上传。朋友看不到 ETA 更新。→ 修复：移除 `onDisappear { stopTracking() }`，追踪仅在 meetup 结束时由 ViewModel 停止
2. **[严重] 首次定位授权后追踪不启动**：`startTrackingIfJoined()` 调用 `requestPermission()`（弹出系统弹窗）后立刻检查 `hasPermission`，用户还未点击允许就已经判定为无权限。→ 修复：新增 `.onChange(of: authorizationStatus)` 监听器，授权后自动重新调用 `startTrackingIfJoined()`
3. **[中] 公共交通 ETA 始终失败**：`MKDirections.calculate()` 请求完整路线（路径几何 + 转弯步骤），Apple Maps 对 transit 的完整路线支持有限。→ 修复：改用 `calculateETA()` 轻量 API，仅请求预估时间，transit 成功率大幅提升
4. **[低] ETA 每 30 秒闪烁 `--`**：`uploadLocation()` 先写一次无 ETA 数据再写一次含 ETA 数据，Firestore listener 在两次写入之间触发导致朋友端短暂显示 `--`。→ 修复：先计算 ETA，再做单次 Firestore 写入

**构建配置**

- `TARGETED_DEVICE_FAMILY` 从 `"1,2"`（iPhone + iPad）改为 `1`（仅 iPhone），主 App 和 Widget 共 4 处
- 移除 Watch App 嵌入：删除 `Embed Watch Content` Build Phase + Watch target dependency（源码保留，Watch 功能延至 v1.1）

**新增 L10n**

- `aiPeakTimezone` / `aiDataStale` / `aiUsageTrend` / `aiTrendNoData` 4 条新翻译

---

### v1.0.1 (11)

**UI 统一：新功能设计系统对齐**

- 新增 `SSColor.meetup` (`#FF6B9D`) 色彩 token，替换所有新功能中的硬编码粉色 hex
- 新增 `SSOpacity.disabled` (0.40) token
- 全面替换：MeetupDetailView / CreateMeetupSheet / ProjectDetailView (meetup 卡片) / UserProfileDetailView (nudge 按钮) / SocialHubView (nudge 开关) 共 22 处 `Color(hex: "#FF6B9D")` → `SSColor.meetup`
- 模糊区域圆圈 `Color(hex: "#5B7FFF")` → `SSColor.brand`
- 透明度统一使用 SSOpacity token：`.opacity(0.12)` → `SSOpacity.tagBackground`，`.opacity(0.1)` → `SSOpacity.border`，`.opacity(0.3)` → `SSOpacity.elevatedShadow`，`.opacity(0.4)` → `SSOpacity.disabled`
- 移除 MeetupDetailView 位置共享 Toggle 的显式 `.tint()` 以匹配全 App toggle 无自定义 tint 的惯例
- Widget 扩展保持直接 Color(hex:) 用法（无 SSColor 访问权限），与现有 DueCountdownLiveActivity 风格一致
- 所有卡片、间距、圆角、字体均已沿用 SSRadius / SSSpacing / SSFont token，无遗留硬编码值

---

### v1.0.1 (10)

**新功能：集合 Live Activity & 灵动岛**

- 加入集合后自动启动 Live Activity，锁屏和灵动岛同步显示集合倒计时 + 3 种 ETA（🚗 驾车 / 🚌 公交 / 🚶 步行）
- `MeetupActivityAttributes`：记录集合标题、地点、时间；`ContentState` 含三种 ETA + `shouldLeaveNow` 状态
- 锁屏视图（`MeetupLockScreenView`）：📍 标题 + 地点，大号倒计时，三列 ETA（图标 + 时间 + 标签），紧急时显示「该出发了!」横幅，渐变背景随紧急程度变色（粉紫 → 橙红 → 绿色已到达）
- 灵动岛展开态：leading 图钉 + 标题，trailing 倒计时，bottom 三种 ETA + 出发提示
- 灵动岛紧凑态：图钉图标 + 倒计时 / "出发!" / "到了"
- 灵动岛最小态：图钉图标 / 感叹号（紧急）
- 出发提醒逻辑：`shouldLeaveNow = 剩余时间 ≤ min(3种ETA) + 5分钟缓冲`
- `MeetupLocationService` 扩展：`startTracking` 新增 `meetupTime`/`meetupTitle`/`placeName` 参数，每次 ETA 更新同步刷新 Live Activity，`stopTracking` 时自动结束
- Widget Bundle 注册 `MeetupLiveActivity()`

---

### v1.0.1 (9)

**改进：集合隐私 + 三种 ETA**

- 位置模糊化：成员坐标上传前模糊至 ~500m 网格精度（`blurCoordinate`），地图上显示模糊区域圆圈而非精确图钉
- 3 种 ETA 并行计算：同时展示 🚗 驾车 / 🚌 公交 / 🚶 步行 三种到达时间，使用 `MKDirections` 分别计算 `.automobile` / `.transit` / `.walking`
- 位置共享开关：成员可在 MeetupDetailView 关闭「共享我的位置」，关闭后地图不显示该成员模糊位置，但仍共享 3 种 ETA
- `MeetupMemberLocation` 模型重构：`latitude`/`longitude` → `approxLatitude`/`approxLongitude`，`etaSeconds`/`transportType` → `etaDrivingSeconds`/`etaTransitSeconds`/`etaWalkingSeconds`，新增 `sharingLocation` 字段，含 backward-compat 解码
- `MeetupLocationService`：新增 `blurCoordinate()` + `calculateAllETAs()` + `isSharingLocation` toggle
- `MeetupDetailView`：地图改用 `MapCircle(radius: 500)` 显示模糊区域，成员列表改为 ETA legend + 三列 ETA chips，`Bindable(locationService)` 绑定共享开关
- `meetupCreateDesc` 更新为「设定地点和时间，成员可查看模糊位置与到达时间」
- 7 条新翻译（共享我的位置 / 关闭后...大致位置 / 成员到达时间 / 驾车 / 公交 / 步行 / 位置已隐藏）

---

### v1.0.1 (8)

**新功能：集合 (Meetup Session)**

- 团队项目新增「发起集合」功能，设定集合地点 + 时间
- 地点搜索：集成 MapKit `MKLocalSearch`，输入关键词即可搜索 POI，选择后显示地图预览
- 成员可加入集合，加入后自动开启位置共享
- `MeetupLocationService`：CLLocationManager 实时定位 + MKDirections 计算 ETA，每 30 秒上传至 Firestore
- `MeetupDetailView`：MapKit 地图显示集合地点（粉色图钉）+ 所有成员位置（emoji 头像标注），成员列表显示距离 + ETA + 交通方式图标 + 位置新鲜度指示灯
- 一键导航：点击「导航前往」直接打开 Apple Maps 导航
- ProjectDetailView 新增 meetupCard：活跃集合时显示倒计时 + 地点 + 参与人数 + 查看详情/结束按钮
- 数据模型：`MeetupSession`（标题/时间/经纬度/地址/参与者）+ `MeetupMemberLocation`（位置/ETA/交通方式/更新时间）
- FirestoreService：`createMeetup` / `endMeetup`（含清理 location docs）/ `joinMeetup` / `updateMeetupLocation` / `listenToMeetupLocations`
- Firestore Rules 新增 `meetupLocations/{uid}` 子集合权限
- `TeamProject` 新增 `activeMeetup: MeetupSession?` 字段（backward compat）
- `ProjectActivity` 新增 `.meetupCreated` / `.meetupEnded` 类型
- Info.plist 新增 `NSLocationWhenInUseUsageDescription`
- 21 条三语翻译（EN + zh-Hant）

---

### v1.0.1 (7)

**新功能：响铃拍一拍 (Ring Nudge)**

- 好友详情页新增「响铃拍 TA」按钮，独立于普通拍一拍
- 两项前置条件：(1) 对方在你的 Profile 上手动开启了「允许 TA 响铃拍我」(2) 对方当前时间轴处于"空闲"（G 状态）
- 发送成功后，Cloud Functions 向对方推送 critical push + 手机响铃
- 对方手机响铃成功后，Cloud Functions 向发起者推送确认通知（"XX 的手机已响铃"）
- 120 秒冷却时间
- `FriendInfo` 新增 `allowRingNudge: Bool`（默认 `false`，需手动开启，逐好友独立控制）
- `FirestoreService`：`updateAllowRingNudge` / `checkRingNudgePermission` / `sendRingNudge` / `getFriendDoc`
- Firestore Rules 新增 `ringNudges` 子集合权限
- `PushNotificationType` 新增 `.ringNudgeReceived` + `.ringNudgeDelivered`
- 加载好友 Profile 时并行查询权限 + 空闲状态，Button 实时反映可用性
- 9 条三语翻译（EN + zh-Hant）

---

### v1.0.1 (6)

**新功能：拍一拍 (Nudge)**

- 好友详情页新增「拍一拍 TA」按钮，点击后写入对方 Firestore `nudges` 子集合
- Cloud Functions 监听写入，向对方推送通知（"XX 拍了拍你"）+ 手机震动
- 60 秒冷却时间，发送成功后绿色勾显示 3 秒
- 社交页新增「允许拍一拍」开关（默认开启），关闭后他人无法拍
- UserProfile / FriendInfo 新增 `allowNudges` 字段，`decodeIfPresent` 向下兼容旧文档（默认 `true`）
- FirestoreService：`updateAllowNudges(uid:allowed:)` + `sendNudge(from:to:senderName:senderEmoji:)`
- Firestore Rules 新增 nudges 子集合权限（任何认证用户可创建，仅接收方可读/删）
- PushNotificationType 新增 `.nudgeReceived`，点击通知自动跳转社交 Tab
- 8 条三语翻译（EN + zh-Hant）

---

### v1.0.1 (5)

**新功能：专注挑战活动**

- 每月累计前台专注满 30 小时可免费获得 3 个月 Pro 功能
- 活动截止日期：2026 年 6 月 30 日
- 仅计入前台专注时间（后台倒计时仍记入个人 Profile 累计时长和次数，但不计入挑战进度）
- 专注页挑战卡片：实时进度条、剩余小时数、「6/30 截止」标签、「仅计入前台专注时间」提示
- 达成时 completion overlay 显示 🏆 + Pro 有效期
- 活动结束后精简卡片显示「活动已结束」+ 剩余 Pro 有效期
- StoreManager 升级：`isPro` 改为计算属性（购买 ∪ 挑战奖励），奖励可叠加续期
- UserProfile 新增 `proRewardExpiresAt` 字段，Firestore 同步

**汇率转换新增货币**

- 新增 🇭🇰 港币 (HKD) — 主 API (ECB) 直接获取
- 新增 🇲🇴 澳门币 (MOP) — 主 API 从 HKD 按 1.03 联系汇率推算，备用 API 直接获取
- 支持的货币对：CAD / USD / AUD / GBP / EUR / JPY / HKD / MOP → CNY

**Tab 管理优化**

- ⚙️ 设置 Tab 锁定在倒数第二位
- ℹ️ 关于 Tab 锁定在最后一位
- 两者均不可被拖动、提升至主 Tab 栏或降级
- Tab 自定义页面底部显示锁定行（🔒 图标 + 不可拖动）
- `pinnedTailTabs` 有序数组替代原 `pinnedLastTabs` Set，保证固定顺序

---

### v1.0.1 (4)

**新功能：待办 (Todo) Tab**

- SwiftData `TodoItem` 模型：标题、备注、emoji、优先级（高/中/低）、可选截止日期
- 待办列表：活跃/已完成两个分区，按优先级 + 截止日排序
- 已完成分区可折叠，支持一键清除
- 新增/编辑页面：emoji 选择网格、优先级胶囊、日期开关 + DatePicker
- 删除确认弹窗

**新功能：专注模式 (Focus) Tab**

- 番茄钟风格计时器：预设 15/25/30/45/60/90 分钟
- 三态控制：开始(渐变+阴影) / 暂停(橙) / 继续(绿) / 放弃(红)
- 视觉效果：渐变背景、径向发光、呼吸动画环、AngularGradient 进度弧 + 追踪光点
- 完成时 overlay 庆祝动画
- emoji 选择器（8 种学习场景）
- 统计栏：今日分钟、累计时长、完成次数
- SwiftData `FocusSession` 模型，支持 `foregroundSeconds` 前台时长记录
- 完成后自动同步 `totalFocusMinutes` 至 Firestore UserProfile
- 社交页个人资料 + 好友详情页展示累计专注时长

**专注模式 UI 深度优化**

- 渐变背景随运行状态变化
- 12pt 圆弧进度环 + AngularGradient + shadow + 光点
- 呼吸缩放动画（运行时 1.0↔1.08）
- 时间显示 48pt thin rounded + numericText 过渡
- 预设选择器渐变高亮卡片
- emoji 选择器缩放动画

**Bug 修复（5 项）**

1. **[严重]** Timer 在滚动时冻结 → 修复：`RunLoop.current.add(timer, forMode: .common)`
2. **[高]** App 切后台 Timer 停止且不恢复 → 修复：`scenePhase` 监听，记录后台时间差，回前台重算 `remainingSeconds`，到时间自动完成
3. **[中]** 用户导航离开未清理 Timer → 修复：`.onDisappear` invalidate timer
4. **[中]** ProjectTimelineView 每行重建 DateFormatter → 修复：`private static let` 缓存
5. **[中]** mainTabs 在 schedule 强制插入后可能超过 maxMainTabs → 修复：`.prefix()` 截断

**Settings 翻译修复**

- `Text("Deadline")` → `L10n.deadline`
- `"Developer & Designer"` → `L10n.aboutDevRole`
- `"Made with ❤️ for international students"` → `L10n.aboutMadeWith`
- 移除 Sync Status section 重复 footer

**翻译审计**

- 全软件扫描补全 24 条缺失翻译
- Todo 功能 13 条、Focus 功能 14 条、Settings/About 3 条、Activity Timeline 17 条
- 专注挑战 10 条新增翻译（EN + zh-Hant）

---

### v1.0.1 (3)

**新功能：团队项目活动时间线**

- 项目详情页新增「项目动态」入口，显示最新一条动态摘要
- 完整时间线页面：左侧彩色竖线 + 圆点，右侧图标/emoji/描述/相对时间
- 10 种活动类型自动记录：成员加入/退出、任务创建/完成/取消完成/分配/删除、项目创建、会议开始/结束
- Firestore 实时监听，队友操作秒级同步

**新功能：多人分配任务**

- 团队项目 Due 支持分配给多个成员（原为单人）
- 添加/编辑任务页面改为多选头像（勾选 badge 切换）
- 任务行/日历卡片显示重叠 emoji 头像栈（最多 3 个），超出显示「N人」
- Firestore 字段从 `assignedTo: String?` 迁移为 `[String]`，自定义 Codable 向下兼容旧文档
- Cloud Functions 通知逻辑同步适配数组格式

**新功能：扫码加入项目**

- 加入项目页面新增「扫码加入」按钮
- AVFoundation 全屏 QR 扫描器，蓝色取景框角标，权限状态三态处理
- 项目设置页展示项目码 QR 图片（CoreImage 生成，12x 缩放）
- 支持 `studysync://project/CODE` 深度链接和裸 8 位码两种格式
- 扫码成功自动填充并提交

**新功能：找回密码**

- 登录页新增「忘记密码？」按钮
- 弹出 `.medium` 半屏 sheet，输入邮箱发送 Firebase 密码重置邮件
- 发送成功显示提示，3 秒后自动关闭

**新功能：日程地图天气**

- 事件详情页地图缩略图叠加当地实时天气（毛玻璃胶囊 + SF Symbol + 气温）
- Open-Meteo 免费 API，WMO 天气码映射 SF Symbols，15 分钟缓存

**Lock Screen 小组件**

- Widget Bundle 新增 accessoryCircular / accessoryRectangular / accessoryInline 三种锁屏组件
- Circular：Gauge 进度环 + emoji；Rectangular：emoji + 标题 + 天数 + ProgressView；Inline：单行文本

**体验优化**

- 隐藏未完成的 App Icon 和 Theme 功能入口（Settings + Paywall）
- 项目邀请接受/拒绝添加加载动画（ProgressView spinner + disabled 状态）
- 登录时自动创建 profile（修复 REST API 创建的账号无 Firestore 文档问题）
- 补全 24 条缺失的三语翻译（Paywall、账号、通知、同步说明等）

**Bug 修复**

1. 社交页角色标签垂直换行（D/e/v/e/l/o/p/e/r）→ 修复：`.fixedSize()` + 布局重构
2. 社交页邮箱文字在右侧大量空白时仍换行 → 修复：移除 Spacer，改用 `.frame(maxWidth: .infinity)`
3. 接受项目邀请无反应 → 修复：Firestore 安全规则增加 `request.resource.data.memberIds` 检查
4. 项目邀请接受后无加载反馈 → 修复：添加 `isAccepting`/`isRejecting` 状态

---

### v1.0.1 (2)

**时间轴体验优化**

- 「我的时间轴」默认进入预览模式（与别人看到的一致），折叠连续相同状态为简洁摘要条
- 点击编辑按钮后展开为完整的 48 格/天编辑网格，支持画笔涂色和拖拽
- 编辑完成后点击「完成」平滑收回预览视图

**翻译与术语修正**

- 「休息」英文翻译从 Sleeping 修正为 Time Off（专业日程术语）
- 清理 Localizable.xcstrings 中 13 条过时（stale）翻译条目
- 移除 2 条 Unicode 损坏条目（`小��` → `小时`、`���签栏��定义`）
- 补全「标签栏自定义」英文/繁体翻译
- 6 处 inline Text() 格式字符串改为 `Text(verbatim:)` 避免错误提取
- 完成全部 610 条 L10n key 的三语翻译审计，确认 en/zh-Hant 全部 translated

---

### v1.0.1 (1)

**新功能：时间轴（Availability Timeline）**

- 7 天 × 48 时段（每 30 分钟一格）可视化周时间轴
- 四色画笔：有空（绿）、也许（黄）、忙碌（红）、休息（灰）
- 点击/拖拽涂色，Firestore 实时保存（0.5s 防抖）
- 查看朋友时间轴（只读折叠视图）
- 无数据时全灰默认，仅编辑后才创建 Firestore 文档（零冷启动开销）
- 社交页新增入口（calendar.badge.clock 图标）

**新功能：会议时间计算（Meeting Time Calculator）**

- 团队项目详情页新增「查找会议时间」卡片
- 自动获取所有开启「分享时间轴」成员的可用时段
- 并行 TaskGroup 拉取 + 扫描连续全员空闲区间
- 当前用户始终参与计算，无需手动开启分享
- 至少 2 人才显示结果，1 人时提示邀请成员
- 日期标题国际化（今天/明天 + setLocalizedDateFormatFromTemplate）

**新功能：分享时间轴开关**

- 社交页新增「分享时间轴」独立开关（与「分享日程」分离）
- UserProfile 新增 shareAvailability 字段，自定义解码器向下兼容旧文档

**同步架构升级**

- SyncedDefaults：UserDefaults ↔ NSUbiquitousKeyValueStore 双写桥接
  - 日历显示天数、已完成事件开关、全天事件开关
  - Live Activity 开关、提前时间、超时时间
  - Deadline 熔岩效果、全局边框、感染效果、紧迫窗口
  - Tab 栏自定义布局
  - 首次启动自动迁移本地值至 iCloud
  - 监听 didChangeExternallyNotification 合并远端更改
- iCloud Keychain 同步 AI API 密钥
  - kSecAttrAccessibleAfterFirstUnlock + kSecAttrSynchronizable
  - 自动迁移旧版 device-only Keychain 条目
  - 删除时清理 synced + legacy 双份
- DeadlineRecord 跨设备稳定性
  - 新增 externalIdentifier 字段（calendarItemExternalIdentifier）
  - matches() 优先匹配 externalIdentifier，回退 eventIdentifier
  - 标记 Deadline 时同时存储两种标识符

**Firestore 优化**

- 增量 Shared Dues 同步（syncDuesIncremental）：diff-based upsert/delete 替代全量清空重写
- 单条 upsert/delete 方法（upsertSharedDue / deleteSharedDue）
- 打卡后自动推送聚合统计到 Firestore（totalCheckIns / longestStreak）
- 登录后自动加载个人时间轴数据

**Settings 增强**

- 新增同步状态卡片：iCloud（蓝）/ Firebase（品牌色）双通道状态指示
- 绿/灰圆点 + 已启用/未登录标签 + 各通道覆盖功能说明

**Bug 修复（5 项）**

1. 会议时间计算排除了当前用户 → 修复：自身始终参与
2. 仅自己 1 人时显示全部空闲为「会议时间」→ 修复：≥2 人才计算
3. 日期标题硬编码中文（今天/明天/M月d日）→ 修复：L10n + 系统日期模板
4. updateSlot 默认值不一致（allAvailable vs allSleeping）→ 统一为 allSleeping
5. DaySlots.parse() 无效字符回退到 .available → 修复：回退到 .sleeping

---

## v1.0.0

首个公开版本。
