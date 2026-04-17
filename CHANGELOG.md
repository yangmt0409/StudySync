# StudySync Changelog

## v1.0.1 Overall

v1.0.1 是 StudySync 的首个功能更新版本，围绕 **多设备同步**、**时间协作**、**个人效率** 和 **稳定性** 四大方向进行了全面升级。新增「时间轴」系统，让用户可以标记一周的空闲/忙碌状态并与朋友互相查看；团队项目新增「会议时间计算」，自动寻找所有成员的共同空闲时段。新增「待办」和「专注模式」两大核心 Tab，配合专注挑战活动（30h/月 → 3 个月 Pro）提升用户留存。同步架构经过全面重构，UserDefaults 偏好设置、AI API 密钥、日历 Deadline 标记均实现跨设备同步。完成全部 L10n 三语翻译审计与清理。

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
