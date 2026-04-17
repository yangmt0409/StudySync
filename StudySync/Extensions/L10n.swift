import Foundation

/// Centralized localization keys.
/// The Chinese text IS the key - Xcode String Catalog will auto-extract these.
/// Add English and Traditional Chinese translations in Localizable.xcstrings
enum L10n {
    // MARK: - App
    static let appName = String(localized: "留时")
    static let appSubtitle = String(localized: "留学生时间追踪")

    // MARK: - Tabs
    static let tabSchedule = String(localized: "日程")
    static let tabCountdown = String(localized: "倒计时")
    static let tabHome = String(localized: "首页")
    static let tabDualClock = String(localized: "双时区")
    static let tabSettings = String(localized: "设置")

    // MARK: - Greetings
    static let greetingMorning = String(localized: "早上好 👋")
    static let greetingNoon = String(localized: "中午好 👋")
    static let greetingAfternoon = String(localized: "下午好 👋")
    static let greetingEvening = String(localized: "晚上好 👋")

    // MARK: - Common Actions
    static let save = String(localized: "保存")
    static let cancel = String(localized: "取消")
    static let delete = String(localized: "删除")
    static let done = String(localized: "完成")
    static let pin = String(localized: "置顶")
    static let unpin = String(localized: "取消置顶")

    // MARK: - Events
    static let addEvent = String(localized: "添加事件")
    static let editEvent = String(localized: "编辑事件")
    static let deleteEvent = String(localized: "删除事件")
    static let eventName = String(localized: "事件名称")
    static let eventInfo = String(localized: "事件信息")
    static let eventDetail = String(localized: "事件详情")
    static let category = String(localized: "分类")
    static let expired = String(localized: "已结束")
    static let daysUnit = String(localized: "天")

    static func daysRemaining(_ days: Int) -> String {
        String(localized: "还有\(days)天")
    }
    static func daysElapsed(_ days: Int) -> String {
        String(localized: "已过\(days)天")
    }
    static func totalDays(_ days: Int) -> String {
        String(localized: "共 \(days) 天")
    }

    // MARK: - Categories
    static let categoryAcademic = String(localized: "学业")
    static let categoryVisa = String(localized: "签证")
    static let categoryTravel = String(localized: "旅行")
    static let categoryLife = String(localized: "生活")

    // MARK: - Dates
    static let date = String(localized: "日期")
    static let startDate = String(localized: "开始日期")
    static let endDate = String(localized: "目标日期")
    static let dateError = String(localized: "目标日期不能早于开始日期")

    // MARK: - Form Sections
    static let iconSection = String(localized: "图标")
    static let cardColor = String(localized: "卡片颜色")
    static let quickAdd = String(localized: "快速添加")
    static let quickAddFooter = String(localized: "选择模板后自动填入，只需修改标题和日期")
    static let options = String(localized: "选项")
    static let pinDisplay = String(localized: "置顶显示")
    static let expiryReminder = String(localized: "到期提醒")
    static let reminderFooter = String(localized: "将在到期前 1天、3天、7天 发送通知提醒")
    static let preview = String(localized: "预览")

    // MARK: - Templates
    static let templateSemester = String(localized: "学期结束倒计时")
    static let templateReturn = String(localized: "回国倒计时")
    static let templateExam = String(localized: "考试倒计时")
    static let templateVisa = String(localized: "签证到期提醒")

    // MARK: - Search & Filter
    static let searchEvents = String(localized: "搜索事件...")
    static let filterAll = String(localized: "全部")
    static let searchCity = String(localized: "搜索城市...")

    // MARK: - Empty State
    static let emptyTitle = String(localized: "还没有倒计时事件")
    static let emptySubtitle = String(localized: "添加你的第一个倒计时\n追踪学期、签证、回国等重要日期")

    // MARK: - Dual Clock
    static let homeLabel = String(localized: "家乡")
    static let studyLabel = String(localized: "留学地")
    static func timeDifference(_ hours: Int) -> String {
        String(localized: "时差 \(hours) 小时")
    }

    // MARK: - Settings
    static let citySettings = String(localized: "城市设置")
    static let homeCity = String(localized: "家乡城市")
    static let studyCity = String(localized: "留学城市")
    static let cityFooter = String(localized: "选择家乡和留学城市，用于双时钟和时差显示")
    static let displaySettings = String(localized: "显示设置")
    static let showExpired = String(localized: "显示已过期事件")
    static let defaultCategory = String(localized: "默认分类")
    static let about = String(localized: "关于")
    static let version = String(localized: "版本")
    static let developer = String(localized: "开发者")
    static let acknowledgements = String(localized: "致谢")
    static let aboutFooter = String(localized: "感谢每一位为 StudySync 做出贡献的人")
    static let contactUs = String(localized: "联系我们")
    static let openSource = String(localized: "开源组件")
    static let more = String(localized: "更多")

    // MARK: - Pro / Paywall
    static let upgradePro = String(localized: "升级到 Pro")
    static let proActivated = String(localized: "已激活")
    static let proFeaturesDesc = String(localized: "解锁无限倒计时、签证提醒等功能")
    static let unlockPro = String(localized: "解锁 StudySync Pro")
    static let oneTimePurchase = String(localized: "一次购买，永久使用")
    static let restorePurchase = String(localized: "恢复购买")
    static let purchaseSuccess = String(localized: "购买成功!")
    static let allProUnlocked = String(localized: "已解锁所有 Pro 功能")

    // MARK: - Detail View
    static let confirmDelete = String(localized: "确认删除")
    static let deleteWarning = String(localized: "删除后无法恢复")
    static let noEvents = String(localized: "暂无事件")

    // MARK: - Notifications
    static let notificationTitle = String(localized: "留时提醒")

    // MARK: - Event Detail Tabs
    static let tabBasic = String(localized: "基本")
    static let tabDisplay = String(localized: "显示")
    static let tabTheme = String(localized: "主题")
    static let tabMore = String(localized: "更多")

    // MARK: - Event Detail - Basic
    static let titleLabel = String(localized: "标题")
    static let emojiLabel = String(localized: "Emoji")
    static let noteSection = String(localized: "备注")
    static let notePlaceholder = String(localized: "添加备注...")

    // MARK: - Event Detail - Display
    static let displayMode = String(localized: "显示模式")
    static let showPercentage = String(localized: "显示百分比")
    static let countUpMode = String(localized: "正计时模式")
    static let timeUnitSection = String(localized: "时间单位")
    static let dotRepresents = String(localized: "每个点代表")
    static let countUpDescription = String(localized: "正计时模式下，显示从开始日期到现在已经过去的时间")

    // MARK: - Event Detail - Theme
    static let themeStyle = String(localized: "主题样式")
    static let dotShapeSection = String(localized: "点的形状")
    static let colorSection = String(localized: "颜色")
    static let backgroundImage = String(localized: "背景图片")
    static let selectImage = String(localized: "选择图片")
    static let removeImage = String(localized: "移除")
    static let fontSection = String(localized: "字体")
    static let textColor = String(localized: "文字颜色")
    static let dotColor = String(localized: "圆球颜色")

    // MARK: - Event Detail - More
    static let generateShareCard = String(localized: "生成分享卡片")
    static let playCelebration = String(localized: "播放庆祝动画")
    static let infoSection = String(localized: "信息")
    static let totalDaysLabel = String(localized: "总天数")
    static let elapsedDaysLabel = String(localized: "已过天数")
    static let remainingDaysLabel = String(localized: "剩余天数")
    static let progressLabel = String(localized: "进度")
    static let createdAtLabel = String(localized: "创建时间")

    // MARK: - Event Detail - Display Text
    static let daysPassed = String(localized: "天已过")
    static let daysLeft = String(localized: "天剩余")
    /// Unit-aware variants: "{unit}已过" / "{unit}剩余"
    static func unitPassed(_ unit: String) -> String {
        String(localized: "\(unit)已过")
    }
    static func unitLeft(_ unit: String) -> String {
        String(localized: "\(unit)剩余")
    }

    // MARK: - Settings - App Icon
    static let appIconSection = String(localized: "App 图标")
    static let appIconFooter = String(localized: "Pro 专属功能：更换 App 桌面图标")
    static let iconDefault = String(localized: "默认")
    static let iconOcean = String(localized: "海洋蓝")
    static let iconSunset = String(localized: "日落橙")
    static let iconForest = String(localized: "森林绿")
    static let iconMidnight = String(localized: "午夜黑")
    static let iconCoral = String(localized: "珊瑚粉")

    // MARK: - Share Card
    static let shareCard = String(localized: "分享卡片")
    static let template = String(localized: "模板")
    static let sizeLabel = String(localized: "尺寸")
    static let saveToPhotos = String(localized: "保存到相册")
    static let share = String(localized: "分享")
    static let savedToPhotos = String(localized: "已保存到相册")
    static let errorTitle = String(localized: "错误")
    static let photoAccessDenied = String(localized: "请在设置中允许访问相册")
    static let completed = String(localized: "已完成！")

    // MARK: - Celebration / Share Templates
    static let templateMinimal = String(localized: "极简风")
    static let templateDotGrid = String(localized: "点阵风")
    static let templateCard = String(localized: "卡片风")

    // MARK: - DualClock defaults
    static let defaultHomeCity = String(localized: "上海")
    static let defaultStudyCity = String(localized: "多伦多")

    // MARK: - Exchange Rate
    static let exchangeRate = String(localized: "汇率")
    static let currencyPair = String(localized: "货币对")
    static let offlineData = String(localized: "离线数据")
    static let updatedAt = String(localized: "更新于 ")

    // MARK: - Calendar Feed
    static let calendar = String(localized: "日程")
    static let tools = String(localized: "工具")
    static let today = String(localized: "今天")
    static let tomorrow = String(localized: "明天")
    static let dayAfterTomorrow = String(localized: "后天")
    static let yesterday = String(localized: "昨天")
    static func daysLater(_ n: Int) -> String { String(localized: "\(n)天后") }
    static func daysAgo(_ n: Int) -> String { String(localized: "\(n)天前") }
    static let noSchedule = String(localized: "没有日程安排")
    static let noRecentSchedule = String(localized: "最近没有日程安排")
    static let enjoyFreeTime = String(localized: "享受自由时光！")
    static let connectCalendar = String(localized: "连接你的日历")
    static let calendarAccessDescription = String(localized: "StudySync 需要访问你的日历来显示课程和事件的实时倒计时。你的数据仅在本地使用，不会上传。")
    static let allowAccess = String(localized: "允许访问")
    static let calendarDenied = String(localized: "日历访问被拒绝")
    static let openSettings = String(localized: "请在系统设置中允许 StudySync 访问你的日历。")
    static let goToSettings = String(localized: "去设置中开启")

    // MARK: - Calendar Settings
    static let scheduleSection = String(localized: "日程")
    static let displayRange = String(localized: "显示范围")
    static let showFinishedEvents = String(localized: "显示已结束事件")
    static let showAllDayEvents = String(localized: "显示全天事件")
    static let scheduleFooter = String(localized: "控制日程 Tab 中显示的事件范围和类型")
    static let days3 = String(localized: "3 天")
    static let days5 = String(localized: "5 天")
    static let days7 = String(localized: "7 天")
    static let days14 = String(localized: "14 天")
    static let days30 = String(localized: "30 天")

    // MARK: - Calendar Event Card
    static let noTitle = String(localized: "无标题")
    static let allDay = String(localized: "全天")
    static let starting = String(localized: "即将开始")
    static let ending = String(localized: "即将结束")
    static let ended = String(localized: "已结束")

    // MARK: - Font Options
    static let fontDefault = String(localized: "默认")
    static let fontRounded = String(localized: "圆体")
    static let fontSerif = String(localized: "衬线")
    static let fontMono = String(localized: "等宽")

    // MARK: - Theme/Dot/TimeUnit Display Names
    static let dotCircle = String(localized: "圆形")
    static let dotSquare = String(localized: "方形")
    static let dotDiamond = String(localized: "菱形")
    static let dotHeart = String(localized: "爱心")
    static let dotStar = String(localized: "星星")
    static let unitDay = String(localized: "天")
    static let unitWeek = String(localized: "周")
    static let unitMonth = String(localized: "月")

    // MARK: - Not Started (future event)
    static let notStartedBadge = String(localized: "等待开始")
    static func startsInDays(_ days: Int) -> String {
        String(localized: "\(days) 天后开始")
    }
    static let themeGrid = String(localized: "点阵")
    static let themeRing = String(localized: "进度环")
    static let themeBar = String(localized: "进度条")
    static let themeMinimal = String(localized: "极简")

    // MARK: - Share Card Strings
    static let shareDaysPassed = String(localized: "天已过")
    static let shareDaysRemaining = String(localized: "天剩余")
    static let shareDaysPassedUpper = String(localized: "DAYS PASSED")
    static let shareDaysLeftUpper = String(localized: "DAYS LEFT")
    static let shareComplete = String(localized: "COMPLETE")
    static func sharePercentComplete(_ percent: Int) -> String {
        String(localized: "\(percent)% 已完成")
    }

    // MARK: - Notification Body
    static func notificationBody(title: String, days: Int) -> String {
        String(localized: "距离 \(title) 还有 \(days) 天")
    }

    // MARK: - Store Errors
    static let productLoadError = String(localized: "无法加载产品信息")
    static let productNotLoaded = String(localized: "产品信息未加载")
    static let purchasePending = String(localized: "购买待处理")
    static func purchaseFailed(_ error: String) -> String {
        String(localized: "购买失败: \(error)")
    }
    static let verificationFailed = String(localized: "购买验证失败")
    static let noRestorableRecord = String(localized: "未找到可恢复的购买记录")
    static func restoreFailed(_ error: String) -> String {
        String(localized: "恢复失败: \(error)")
    }
    static let networkError = String(localized: "网络请求失败")

    // MARK: - Paywall
    static let feature = String(localized: "功能")
    static let countdownEvents = String(localized: "倒计时事件")
    static let fiveLimit = String(localized: "5个")
    static let oneLimit = String(localized: "1个")
    static let threeLimit = String(localized: "3个")
    static let unlimited = String(localized: "无限")
    static let visaReminder = String(localized: "签证到期提醒")
    static let widgetThemes = String(localized: "Widget 多主题")
    static let customAppIcon = String(localized: "自定义 App Icon")
    static let basicCountdown = String(localized: "基础倒计时")
    static let dualClockDisplay = String(localized: "双时区显示")
    static let iCloudSync = String(localized: "iCloud 同步")
    static let teamProjects = String(localized: "团队项目")
    static let studyGoals = String(localized: "学习目标")
    static let countdownCustomization = String(localized: "倒计时背景/字体/配色")
    static let shareCardNoWatermark = String(localized: "分享卡片无水印")
    static let aiMonitorFree = String(localized: "AI 用量监控")
    static let socialFeatures = String(localized: "社交 / 好友")
    static let cloudSyncAllFree = String(localized: "云端同步")
    static let comingSoon = String(localized: "即将推出")
    static let sandboxBannerTitle = String(localized: "TestFlight 测试版 · 放心点购买")
    static let sandboxBannerBody = String(localized: "检测到你是通过 TestFlight 安装的，所有购买都走 Apple 沙盒环境，不会真实扣款。请放心点击下方按钮完成测试购买。")
    static let signOutConfirmTitle = String(localized: "确认登出?")
    static let signOutConfirmMessage = String(localized: "登出后本设备将停止从云端同步新的数据，社交、团队、通知功能也会暂停。已下载到本地的倒计时和学习目标会保留，重新登录即可继续同步。")
    static let notifActionOpen = String(localized: "查看")
    static let notifActionSnooze = String(localized: "明天再提醒")
    static let notifActionMarkSeen = String(localized: "忽略")

    // MARK: - Onboarding
    static let onboardingSkip = String(localized: "跳过")
    static let onboardingNext = String(localized: "下一步")
    static let onboardingAllowNotif = String(localized: "允许通知")
    static let onboardingGetStarted = String(localized: "开始使用")
    static let onboardingWelcomeTitle = String(localized: "欢迎来到 StudySync")
    static let onboardingWelcomeSubtitle = String(localized: "为留学生打造的一站式时间管理 App — 倒计时、学习目标、双时区、AI 用量，全都在这里。")
    static let onboardingFeaturesTitle = String(localized: "你可以做什么")
    static let onboardingFeatureCountdown = String(localized: "倒计时事件")
    static let onboardingFeatureCountdownDesc = String(localized: "考试、签证、回国机票、截止日期——一眼看清还剩多少天。")
    static let onboardingFeatureDualClock = String(localized: "双时区时钟")
    static let onboardingFeatureDualClockDesc = String(localized: "同时显示留学地和家乡时间，打电话再也不怕时差。")
    static let onboardingFeatureGoals = String(localized: "学习目标打卡")
    static let onboardingFeatureGoalsDesc = String(localized: "每日目标、连续打卡、里程碑庆祝，养成长期习惯。")
    static let onboardingFeatureTeam = String(localized: "团队项目协作")
    static let onboardingFeatureTeamDesc = String(localized: "和同学一起分配任务、管理 due，小组作业不再掉链子。")
    static let onboardingNotifTitle = String(localized: "开启通知提醒")
    static let onboardingNotifSubtitle = String(localized: "我们会在 deadline 前 1 / 3 / 7 天提醒你。你可以随时在设置里关闭。")
    static let onboardingNotifGranted = String(localized: "通知已开启")
    static let onboardingNotifDenied = String(localized: "已跳过，可在系统设置中手动开启")
    static let onboardingReadyTitle = String(localized: "一切就绪")
    static let onboardingReadySubtitle = String(localized: "我们已经给你准备了几个示例事件，你可以随时删除它们或添加自己的。")
    static func upgradePriceButton(_ price: String) -> String {
        String(localized: "升级 Pro - \(price)")
    }

    // MARK: - Calendar Event CRUD
    static let calAddCalEvent = String(localized: "添加日历事件")
    static let calEditCalEvent = String(localized: "编辑日历事件")
    static let calDeleteEvent = String(localized: "删除日历事件")
    static let calEventDetail = String(localized: "事件详情")
    static let calViewDetail = String(localized: "查看详情")
    static let calDuplicateEvent = String(localized: "复制事件")
    static let calEventTitle = String(localized: "事件标题")
    static let calAllDayEvent = String(localized: "全天事件")
    static let calStartTime = String(localized: "开始时间")
    static let calEndTime = String(localized: "结束时间")
    static let calSaveToCalendar = String(localized: "保存到日历")
    static let calLocation = String(localized: "地点")
    static let calLocationPlaceholder = String(localized: "输入地点...")
    static let calLocationSearch = String(localized: "搜索地点...")
    static let calReminder = String(localized: "提醒")
    static let calRepeat = String(localized: "重复")
    static let calBelongsToCalendar = String(localized: "所属日历")
    static let calReadOnly = String(localized: "只读日历")
    static let calInProgress = String(localized: "进行中")

    // Alarm options
    static let calAlarmNone = String(localized: "无提醒")
    static let calAlarm5min = String(localized: "5 分钟前")
    static let calAlarm15min = String(localized: "15 分钟前")
    static let calAlarm30min = String(localized: "30 分钟前")
    static let calAlarm1hour = String(localized: "1 小时前")
    static let calAlarm1day = String(localized: "1 天前")
    static let calAlarmCustom = String(localized: "自定义")
    static let calAlarmCustomBefore = String(localized: "提前提醒")
    static let calAlarmHourUnit = String(localized: "小时")
    static let calAlarmMinUnit = String(localized: "分钟")
    static let calAddReminder = String(localized: "添加提醒")
    static let calReminderMax = String(localized: "最多可设置 5 个提醒")

    // Alarm description helpers
    static func calAlarmMinBefore(_ min: Int) -> String {
        String(localized: "\(min) 分钟前提醒")
    }
    static func calAlarmHourBefore(_ hours: Int) -> String {
        String(localized: "\(hours) 小时前提醒")
    }
    static func calAlarmDayBefore(_ days: Int) -> String {
        String(localized: "\(days) 天前提醒")
    }

    // Recurrence options
    static let calRepeatNone = String(localized: "不重复")
    static let calRepeatDaily = String(localized: "每天")
    static let calRepeatWeekly = String(localized: "每周")
    static let calRepeatBiweekly = String(localized: "每两周")
    static let calRepeatMonthly = String(localized: "每月")
    static let calRepeatYearly = String(localized: "每年")

    // Quick templates
    static let calQuickTemplates = String(localized: "快捷模板")
    static let calTemplateCourse = String(localized: "课程")
    static let calTemplateExam = String(localized: "考试")
    static let calTemplateDeadline = String(localized: "作业截止")
    static let calTemplateOfficeHours = String(localized: "Office Hours")
    static let calTemplateGroupMeeting = String(localized: "小组讨论")

    // Delete alerts
    static let calDeleteConfirmMessage = String(localized: "确认删除此日历事件？此操作无法撤销。")
    static let calDeleteRecurringMessage = String(localized: "这是一个重复事件，你想如何删除？")
    static let calDeleteThisOnly = String(localized: "仅删除此事件")
    static let calDeleteAllFuture = String(localized: "删除此事件及之后的所有重复事件")

    // Toast messages
    static let calEventCreated = String(localized: "事件已创建")
    static let calEventUpdated = String(localized: "事件已更新")
    static let calEventDeleted = String(localized: "事件已删除")
    static let calEventDuplicated = String(localized: "事件已复制")

    // Duration formatting
    static func calDurationHourMin(_ hours: Int, _ mins: Int) -> String {
        String(localized: "\(hours) 小时 \(mins) 分钟")
    }
    static func calDurationHour(_ hours: Int) -> String {
        String(localized: "\(hours) 小时")
    }
    static func calDurationMin(_ mins: Int) -> String {
        String(localized: "\(mins) 分钟")
    }

    // Countdown in detail
    static func calStartsIn(_ time: String) -> String {
        String(localized: "\(time) 后开始")
    }

    // Write permission needed
    static let calNeedWriteAccess = String(localized: "需要日历写入权限")
    static let calNeedWriteAccessDesc = String(localized: "请在系统设置中允许 StudySync 写入日历事件。")

    // MARK: - Deadline
    static let dlDeadlineLabel = String(localized: "Due")
    static let dlMarkAsDeadline = String(localized: "标记为 Due")
    static let dlRemoveDeadline = String(localized: "取消 Due 标记")
    static let dlMarkedAsDeadline = String(localized: "已标记为 Due")
    static let dlRemovedDeadline = String(localized: "已取消 Due 标记")
    static let dlMarkComplete = String(localized: "标记完成")
    static let dlMarkIncomplete = String(localized: "取消完成")
    static let dlCompleted = String(localized: "已完成")
    static let dlOverdue = String(localized: "已逾期")

    // Deadline Settings
    static let dlLavaEffect = String(localized: "岩浆紧迫感效果")
    static let dlGlobalBorder = String(localized: "全局边框发光")
    static let dlInfectNearby = String(localized: "感染周围事件")
    static let dlUrgencyWindow = String(localized: "紧迫提醒开始时间")
    static let dlWindow1h = String(localized: "1 小时前")
    static let dlWindow3h = String(localized: "3 小时前")
    static let dlWindow6h = String(localized: "6 小时前")
    static let dlWindow10h = String(localized: "10 小时前")
    static let dlWindow12h = String(localized: "12 小时前")
    static let dlWindow24h = String(localized: "24 小时前")
    static let dlSettingsFooter = String(localized: "Deadline 临近时，App 界面会逐渐显示岩浆色升温效果。关闭后所有视觉效果停止。")

    // MARK: - Live Activity
    static let laLiveActivity = String(localized: "实时活动")
    static let laEnabled = String(localized: "Due 实时倒计时")
    static let laLeadTime = String(localized: "启动时机")
    static let laLead60 = String(localized: "提前 1 小时")
    static let laLead30 = String(localized: "提前 30 分钟")
    static let laLead15 = String(localized: "提前 15 分钟")
    static let laOverdueTimeout = String(localized: "超时自动结束")
    static let laTimeout5 = String(localized: "5 分钟")
    static let laTimeout10 = String(localized: "10 分钟")
    static let laTimeout30 = String(localized: "30 分钟")
    static let laSettingsFooter = String(localized: "Due 事件临近时，在锁屏和灵动岛显示实时倒计时。")

    // MARK: - AI Monitor
    static let aiMonitor = String(localized: "AI 监控")
    static let aiNoAccounts = String(localized: "还没有 AI 账户")
    static let aiNoAccountsDesc = String(localized: "关联你的 AI 服务账户\n实时追踪用量和剩余额度")
    static let aiAddAccount = String(localized: "添加账户")
    static let aiAddAccountDesc = String(localized: "选择你要关联的 AI 服务，登录后自动追踪用量。")
    static let aiDeleteAccount = String(localized: "删除账户")
    static let aiDeleteConfirm = String(localized: "删除后登录凭证也会从设备中移除，此操作无法撤销。")
    static let aiLow = String(localized: "用量高")
    static let aiExpired = String(localized: "已过期")
    static let aiLastUpdated = String(localized: "上次更新：")
    static let aiUsageRefreshed = String(localized: "用量已刷新")
    static let aiLowBalanceTitle = String(localized: "AI 用量提醒")
    static let aiLowBalanceWarning = String(localized: "用量已超过阈值")
    static let aiSessionExpired = String(localized: "登录已过期，请重新登录。")
    static let aiNoOrganization = String(localized: "未找到关联的组织。")
    static let aiConnecting = String(localized: "正在连接...")
    static let aiRelogin = String(localized: "重新登录")
    static let aiReloginDesc = String(localized: "登录已过期，请重新登录以继续获取用量数据。")

    // Usage windows
    static let ai5hWindow = String(localized: "5 小时窗口")
    static let ai7dWindow = String(localized: "7 天窗口")
    static let ai5hSession = String(localized: "5 小时会话")
    static let ai7dWeekly = String(localized: "7 天周期")

    // OpenAI / Codex
    static let aiCodexTasks = String(localized: "Codex 任务")
    static let aiCodexUsage = String(localized: "Codex 用量")
    static let aiCodexNoData = String(localized: "暂无 Codex 用量数据")
    static let aiChatStatus = String(localized: "对话状态")
    static let aiChatNormal = String(localized: "正常")
    static let aiChatLimited = String(localized: "已限流")
    static let aiPlanInfo = String(localized: "订阅信息")

    // Detail view
    static let aiUsageDetail = String(localized: "用量详情")
    static let aiPeakUsage = String(localized: "峰值用量")
    static let aiPerModel = String(localized: "按模型")
    static let aiExtraUsage = String(localized: "Extra Usage")
    static let aiEnabled = String(localized: "已启用")
    static let aiSettings = String(localized: "提醒设置")
    static let aiNotifyAt = String(localized: "用量提醒阈值")
    static let aiUsagePage = String(localized: "用量页面")

    // Add account
    static let aiAlreadyAdded = String(localized: "已添加")
    static let aiAutoTrack = String(localized: "自动追踪用量")
    static let aiWebViewTrack = String(localized: "网页查看用量")
    static let aiConfirmLoggedIn = String(localized: "已登录，添加账户")
    static let aiTapToViewUsage = String(localized: "点击查看用量详情")
    static let aiViewUsagePage = String(localized: "查看用量页面")
    static let aiWebViewDesc = String(localized: "该服务暂不支持自动获取用量数据，\n请在网页中查看。")

    static let aiPeakHour = String(localized: "Peak Hour")
    static let aiPeakHourDesc = String(localized: "当前为高峰时段，用量消耗 2x")
    static func aiPeakEndsHM(hours: Int, mins: Int) -> String {
        String(localized: "\(hours)h\(mins)m 后结束")
    }
    static func aiPeakEndsM(mins: Int) -> String {
        String(localized: "\(mins)m 后结束")
    }
    static func aiPeakEndsInHM(hours: Int, mins: Int) -> String {
        String(localized: "距离结束还有 \(hours) 小时 \(mins) 分钟")
    }
    static func aiPeakEndsInM(mins: Int) -> String {
        String(localized: "距离结束还有 \(mins) 分钟")
    }

    static func aiLoginTo(provider: String) -> String {
        String(localized: "登录 \(provider)")
    }
    static func aiResetsAt(time: String) -> String {
        String(localized: "\(time) 重置")
    }
    static func aiResetsInTime(hours: Int, mins: Int) -> String {
        if hours > 0 {
            return String(localized: "\(hours) 小时 \(mins) 分钟后重置")
        }
        return String(localized: "\(mins) 分钟后重置")
    }
    static func aiUsageAlert(provider: String, percent: Int, window: String) -> String {
        String(localized: "\(provider) \(window)用量已达 \(percent)%，请注意控制使用。")
    }
    static func aiErrorAPI(code: Int) -> String {
        String(localized: "API 请求失败 (\(code))")
    }

    // 5-hour session reset notification
    static func aiResetNotificationTitle(provider: String) -> String {
        String(localized: "\(provider) 5 小时会话已重置")
    }
    static let aiResetNotificationBody = String(localized: "你的 5 小时会话额度已恢复，可以继续使用了。")

    // Scraping
    static let aiScrapeFailedRetry = String(localized: "获取用量失败，请稍后重试")
    static let aiScrapeParseError = String(localized: "用量数据解析失败")

    // Provider-specific windows
    static let ai3hWindow = String(localized: "3 小时窗口")
    static let ai3hSession = String(localized: "3 小时会话")
    static let aiDailyWindow = String(localized: "每日额度")
    static let aiDailyUsage = String(localized: "每日用量")
    static let aiWeeklyWindow = String(localized: "每周额度")
    static let aiWeeklyUsage = String(localized: "每周用量")

    // MARK: - Study Goals
    static let goalTitle = String(localized: "学习目标")
    static let goalAddGoal = String(localized: "添加目标")
    static let goalNameSection = String(localized: "目标名称")
    static let goalTitlePlaceholder = String(localized: "例如：每日阅读30分钟")
    static let goalFrequency = String(localized: "打卡频率")
    static let goalDaily = String(localized: "每日打卡")
    static let goalWeekly = String(localized: "每周打卡")
    static let goalDailyDesc = String(localized: "每天打卡一次，坚持每日习惯")
    static let goalWeeklyDesc = String(localized: "每周打卡一次，适合长周期目标")
    static let goalCheckIn = String(localized: "打卡")
    static let goalCheckedIn = String(localized: "已打卡")
    static let goalCheckInNow = String(localized: "立即打卡")
    static let goalAlreadyCheckedIn = String(localized: "今天已打卡")
    static let goalUndoCheckIn = String(localized: "撤销今日打卡")
    static let goalStreak = String(localized: "连续")
    static let goalTotal = String(localized: "累计")
    static let goalDaysSince = String(localized: "已坚持")
    static let goalEmptyTitle = String(localized: "还没有学习目标")
    static let goalEmptySubtitle = String(localized: "设置学习目标，每天打卡记录\n见证自己的成长与坚持")
    static let goalMaxHint = String(localized: "最多同时进行 3 个目标")
    static let goalArchived = String(localized: "已归档")
    static let goalArchiveGoal = String(localized: "归档目标")
    static let goalDeleteGoal = String(localized: "删除目标")
    static let goalDeleteWarning = String(localized: "删除后所有打卡记录将被清除，无法恢复")
    static let goalReactivate = String(localized: "重新激活")
    static let goalMilestones = String(localized: "里程碑")
    static let goalMilestoneReached = String(localized: "达成里程碑！")
    static let goalAllMilestones = String(localized: "所有里程碑已达成")
    static let goalHistory = String(localized: "打卡记录")
    static let goalNoCheckIns = String(localized: "还没有打卡记录")

    static func goalStreakCount(_ count: Int) -> String {
        String(localized: "连续 \(count) 次")
    }
    static func goalTotalCheckIns(_ count: Int) -> String {
        String(localized: "累计 \(count) 次")
    }
    static func goalSince(_ date: String) -> String {
        String(localized: "开始于 \(date)")
    }
    static func goalDayCount(_ count: Int) -> String {
        String(localized: "\(count) 天")
    }
    static func goalWeekCount(_ count: Int) -> String {
        String(localized: "\(count) 周")
    }
    static func goalMilestoneBody(title: String, count: Int) -> String {
        String(localized: "「\(title)」已坚持 \(count) 次，继续加油！")
    }

    // Milestone names
    static let goalMilestone10d = String(localized: "初见成效")
    static let goalMilestone30d = String(localized: "养成习惯")
    static let goalMilestone50d = String(localized: "坚持不懈")
    static let goalMilestone100d = String(localized: "百日之约")
    static let goalMilestone5w = String(localized: "初见成效")
    static let goalMilestone10w = String(localized: "稳步前行")
    static let goalMilestone20w = String(localized: "半程达人")
    static let goalMilestone50w = String(localized: "一年之约")

    // MARK: - Social / Friends
    static let socialTitle = String(localized: "社交")
    static let socialWelcome = String(localized: "加入 StudySync 社区")
    static let socialWelcomeDesc = String(localized: "登录后可以添加好友、查看彼此的 Due 进度")
    static let socialLogin = String(localized: "登录")
    static let socialRegister = String(localized: "注册")
    static let socialLogout = String(localized: "退出登录")
    static let socialLoginFailed = String(localized: "登录失败，请重试")
    static let socialOrEmail = String(localized: "或使用邮箱")
    static let socialEmail = String(localized: "邮箱")
    static let socialPassword = String(localized: "密码")
    static let socialDisplayName = String(localized: "昵称")
    static let socialNoAccount = String(localized: "还没有账号？注册")
    static let socialHasAccount = String(localized: "已有账号？登录")

    // Profile
    static let socialAvatar = String(localized: "头像")
    static let socialEditProfile = String(localized: "编辑资料")
    static let socialAccountInfo = String(localized: "账户信息")
    static let socialJoined = String(localized: "加入时间")
    static let socialCopy = String(localized: "复制")

    // Friend Code
    static let socialFriendCode = String(localized: "好友码")
    static let socialFriendCodeDesc = String(localized: "分享你的好友码给朋友，让他们添加你")
    static let socialMyCode = String(localized: "我的好友码")
    static let socialEnterCode = String(localized: "输入好友的好友码")

    // Friends
    static let socialFriends = String(localized: "好友")
    static let socialAddFriend = String(localized: "添加好友")
    static let socialAddFriendDesc = String(localized: "通过好友码添加朋友，互相查看学习进度")
    static let socialSearch = String(localized: "搜索")
    static let socialSendRequest = String(localized: "发送请求")
    static let socialRequestSent = String(localized: "好友请求已发送")
    static let socialRequestFailed = String(localized: "发送失败，请重试")
    static let socialFriendRequests = String(localized: "好友请求")
    static let socialWantsToAdd = String(localized: "想要添加你为好友")
    static let socialNoFriends = String(localized: "还没有好友")
    static let socialNoFriendsDesc = String(localized: "添加好友后可以查看彼此的 Due 进度和学习成就")
    static let socialCannotAddSelf = String(localized: "不能添加自己")
    static let socialUserNotFound = String(localized: "未找到该用户")

    // Due Sharing
    static let socialShareDues = String(localized: "分享 Due 给好友")
    static let socialShareDuesDesc = String(localized: "开启后好友可以查看你的 Due 事件进度")
    static let socialViewDues = String(localized: "查看 Due")
    static let socialDueEvents = String(localized: "Due 事件")
    static let socialDueShared = String(localized: "已共享")
    static let socialDueNotShared = String(localized: "对方未开启共享")
    static let socialDueNotSharedDesc = String(localized: "该好友还没有开启 Due 共享功能")
    static let socialNoDues = String(localized: "暂无 Due 事件")

    // Badges
    static let socialBadges = String(localized: "徽章")
    static let socialBadgesEarned = String(localized: "已获得徽章")
    static let badgeCatStreak = String(localized: "连续打卡")
    static let badgeCatSocial = String(localized: "社交达人")
    static let badgeCatMilestone = String(localized: "成长里程碑")

    // Badge names
    static let badgeStreak7 = String(localized: "一周勇士")
    static let badgeStreak7Desc = String(localized: "连续打卡 7 天")
    static let badgeStreak30 = String(localized: "月度之星")
    static let badgeStreak30Desc = String(localized: "连续打卡 30 天")
    static let badgeStreak100 = String(localized: "百日王者")
    static let badgeStreak100Desc = String(localized: "连续打卡 100 天")
    static let badgeFirstFriend = String(localized: "初识好友")
    static let badgeFirstFriendDesc = String(localized: "添加第一个好友")
    static let badgeSocial5 = String(localized: "社交蝴蝶")
    static let badgeSocial5Desc = String(localized: "拥有 5 个好友")
    static let badgeTeamPlayer = String(localized: "团队伙伴")
    static let badgeTeamPlayerDesc = String(localized: "开启 Due 共享")
    static let badgeCheckin10 = String(localized: "起步之星")
    static let badgeCheckin10Desc = String(localized: "累计打卡 10 次")
    static let badgeCheckin50 = String(localized: "坚持达人")
    static let badgeCheckin50Desc = String(localized: "累计打卡 50 次")
    static let badgeCheckin100 = String(localized: "百次成就")
    static let badgeCheckin100Desc = String(localized: "累计打卡 100 次")
    static let badgeGoal3 = String(localized: "目标满员")
    static let badgeGoal3Desc = String(localized: "同时拥有 3 个学习目标")

    // Showcase Badges
    static let socialShowcaseBadges = String(localized: "展示徽章")
    static let socialShowcaseBadgesDesc = String(localized: "选择最多 3 个徽章展示在个人资料上")
    static let socialShowcaseMax = String(localized: "最多展示 3 个")
    static let socialNoEarnedBadges = String(localized: "还没有获得徽章")
    static let socialNoEarnedBadgesDesc = String(localized: "完成成就后可以选择展示")

    // MARK: - User Roles
    static let roleDeveloper = String(localized: "开发者")
    static let rolePro = String(localized: "Pro")
    static let roleTester = String(localized: "测试员")
    static let roleEarlyBird = String(localized: "先锋用户")
    static let roleContributor = String(localized: "贡献者")

    // MARK: - User Profile Detail
    static let profileDetail = String(localized: "个人资料")
    static let profileMemberSince = String(localized: "加入于")
    static let profileStats = String(localized: "学习数据")
    static let profileBadgesSection = String(localized: "获得的徽章")
    static let profileNoBadges = String(localized: "暂无徽章")
    static let profileNoBadgesDesc = String(localized: "完成打卡和社交成就即可获得徽章")
    static let profileViewDues = String(localized: "查看 Due 进度")
    static let profileViewTimeline = String(localized: "查看时间轴")
    static func profileBadgeCount(_ earned: Int, _ total: Int) -> String {
        String(localized: "\(earned) / \(total) 已解锁")
    }

    // MARK: - Availability Timeline
    static let avTitle = String(localized: "时间轴")
    static let avMyTimeline = String(localized: "我的时间轴")
    static let avAvailable = String(localized: "有空")
    static let avMaybe = String(localized: "也许")
    static let avBusy = String(localized: "忙碌")
    static let avSleeping = String(localized: "休息")
    static let avFriendTimelines = String(localized: "朋友的时间轴")
    static let avViewFriend = String(localized: "查看时间轴")
    static let avNoData = String(localized: "暂无时间轴数据")
    static let avResetWeek = String(localized: "重置本周")
    static let avResetConfirm = String(localized: "将所有时段重置为有空？")
    static let avHint = String(localized: "选择颜色后点击或拖动来标记时间")
    static let avPreviewHint = String(localized: "这是别人看到的你的时间轴")
    static let avNotConfigured = String(localized: "该用户尚未设置时间轴")
    static func avFriendTitle(_ name: String) -> String {
        String(localized: "\(name) 的时间轴")
    }

    // Share Availability
    static let avShareAvailability = String(localized: "分享时间轴")
    static let avShareAvailabilityDesc = String(localized: "开启后团队项目成员可以查看你的时间轴并计算会议时间")

    // Meeting Time
    static let avMeetingTime = String(localized: "会议时间")
    static let avMeetingTimeDesc = String(localized: "所有开启分享的成员都有空的时间")
    static let avNoMeetingTime = String(localized: "本周暂无共同空闲时间")
    static let avNoMeetingTimeDesc = String(localized: "成员们的空闲时间没有重叠，试试协调各自的时间轴")
    static let avMeetingLoading = String(localized: "正在计算共同空闲时间…")
    static let avFindMeetingTime = String(localized: "查找会议时间")
    static let avFindMeetingTimeDesc = String(localized: "自动计算所有成员都空闲的时段")
    static func avMeetingSlotsFound(_ count: Int) -> String {
        String(localized: "找到 \(count) 个可用时段")
    }
    static func avMeetingParticipants(_ count: Int) -> String {
        String(localized: "\(count) 位成员参与")
    }
    static let avNoSharingMembers = String(localized: "暂无成员开启时间轴分享")
    static let avNoSharingMembersDesc = String(localized: "成员需要在社交页面开启「分享时间轴」")
    static let avEnableShareHint = String(localized: "前往社交页面开启分享")
    static let avToday = String(localized: "今天")
    static let avTomorrow = String(localized: "明天")

    // MARK: - Tab Customization
    static let tabCustomization = String(localized: "标签栏自定义")
    static let tabCustomizationFooter = String(localized: "自定义哪些标签显示在底部标签栏，其余收纳在「更多」中。")
    static let tabBarSection = String(localized: "标签栏")
    static let tabBarFooter = String(localized: "拖动排序，点击 − 移入「更多」。至少保留 2 个标签。")
    static let moreSection = String(localized: "更多")
    static let moreSectionFooter = String(localized: "这些标签会显示在「更多」页面中。点击 + 移回标签栏。")
    static let tabBarDisplayCount = String(localized: "导航栏标签数")
    static let tabBarDisplayCountFooter = String(localized: "调整底部导航栏显示的标签数量，其余标签收纳在「更多」页面中。")
    static let tabCustomizeDragFooter = String(localized: "拖动调整标签顺序。排在前面的标签显示在导航栏，其余在「更多」中。")
    static let resetTabLayout = String(localized: "恢复默认布局")
    static let resetTabLayoutConfirm = String(localized: "将标签栏恢复为默认布局，确定吗？")
    static let reset = String(localized: "恢复")

    // MARK: - iCloud Sync
    static let iCloudSyncFooter = String(localized: "登录账号后，你的所有数据会通过云端账号自动在各设备间同步，重装 App 也能一键恢复。iCloud 为可选的本地备份通道，更改此设置需要重启 App。")
    static let iCloudSyncRestartTitle = String(localized: "需要重启 App")
    static let iCloudSyncRestartMessage = String(localized: "iCloud 同步设置已更改，请手动关闭并重新打开 App 以使更改生效。")

    // Sync Status
    static let syncStatus = String(localized: "同步状态")
    static let syncChannel = String(localized: "同步通道")
    static let syncEnabled = String(localized: "已开启")
    static let syncDisabled = String(localized: "未开启")
    static let syncNotLoggedIn = String(localized: "未登录")
    static let syncICloudItems = String(localized: "可选本地备份通道")
    static let syncFirebaseItems = String(localized: "倒计时 · 学习目标 · 打卡 · 截止日期 · 偏好设置 · 好友 · 团队项目")

    // MARK: - Team Projects

    static let projectTitle = String(localized: "团队项目")
    static let projectCreate = String(localized: "创建项目")
    static let projectJoin = String(localized: "加入项目")
    static let projectName = String(localized: "项目名称")
    static let projectEmoji = String(localized: "项目图标")
    static let projectColor = String(localized: "项目颜色")
    static let projectCode = String(localized: "项目码")
    static let projectEnterCode = String(localized: "输入项目码")
    static let projectMembers = String(localized: "成员")
    static func projectMemberCount(_ count: Int) -> String {
        String(localized: "\(count) 人")
    }
    static let projectInviteFriend = String(localized: "邀请好友")
    static let projectInvites = String(localized: "项目邀请")
    static let projectSettings = String(localized: "项目设置")
    static let projectArchive = String(localized: "存档项目")
    static let projectArchived = String(localized: "已存档")
    static let projectArchivedProjects = String(localized: "已存档项目")
    static let projectLeave = String(localized: "退出项目")
    static let projectDelete = String(localized: "删除项目")
    static let projectEmpty = String(localized: "还没有项目")
    static let projectEmptyDesc = String(localized: "创建或加入一个团队项目，和伙伴一起管理 Due")
    static let projectInviteBanner = String(localized: "邀请伙伴加入项目，一起协作！")
    static let projectJoinSuccess = String(localized: "成功加入项目")
    static let projectJoinError = String(localized: "加入项目失败，请重试")
    static let projectNotFound = String(localized: "未找到该项目")
    static let projectAlreadyMember = String(localized: "你已经是该项目的成员")
    static let projectLeaveConfirm = String(localized: "确定要退出该项目吗？")
    static let projectArchiveConfirm = String(localized: "存档后项目将移至已存档列表，所有成员仍可查看。")
    static let projectDeleteConfirm = String(localized: "删除后项目将永久移除，此操作不可撤销。")
    static let projectOwner = String(localized: "创建者")
    static let projectMember = String(localized: "成员")
    static let projectCopyCode = String(localized: "复制项目码")
    static let projectCodeCopied = String(localized: "项目码已复制")
    static let projectScanQR = String(localized: "扫码加入")
    static let projectInvalidQR = String(localized: "无效的邀请二维码")

    // QR Scanner
    static let qrScanTitle = String(localized: "扫描二维码")
    static let qrScanHint = String(localized: "将二维码对准取景框")
    static let qrPermissionPrompt = String(localized: "需要相机权限才能扫描二维码")
    static let qrAllowCamera = String(localized: "允许相机")
    static let qrPermissionDenied = String(localized: "相机权限已被拒绝，请在设置中开启")
    static let qrOpenSettings = String(localized: "打开设置")

    // Password Reset
    static let authForgotPassword = String(localized: "忘记密码？")
    static let authResetTitle = String(localized: "重置密码")
    static let authResetSubtitle = String(localized: "输入你的邮箱，我们会发送一封重置密码的邮件")
    static let authResetSendButton = String(localized: "发送重置邮件")
    static let authResetSent = String(localized: "重置邮件已发送，请检查你的收件箱")
    static let authResetEmptyEmail = String(localized: "请输入邮箱地址")

    // Project Dues
    static let projectDues = String(localized: "任务")
    static let projectAddDue = String(localized: "添加任务")
    static let projectEditDue = String(localized: "编辑任务")
    static let projectDueTitle = String(localized: "任务标题")
    static let projectDueDesc = String(localized: "任务描述")
    static let projectDueDate = String(localized: "截止日期")
    static let projectDuePriority = String(localized: "优先级")
    static let projectDueAssign = String(localized: "分配给")
    static let projectDueUnassigned = String(localized: "未分配")
    static let projectDueCompleted = String(localized: "已完成")
    static let projectDueOverdue = String(localized: "已逾期")
    static let projectDueAll = String(localized: "全部")
    static let projectDueMine = String(localized: "我的")
    static let projectDueOpen = String(localized: "进行中")
    static let projectNoDues = String(localized: "还没有任务")
    static let projectNoDuesDesc = String(localized: "点击 + 创建第一个任务")
    static let projectPriorityLow = String(localized: "低")
    static let projectPriorityMedium = String(localized: "中")
    static let projectPriorityHigh = String(localized: "高")
    static let projectDueCreatedBy = String(localized: "创建者")
    static func projectDueDaysLeft(_ days: Int) -> String {
        String(localized: "还剩 \(days) 天")
    }
    static let projectDueToday = String(localized: "今天截止")
    static let projectDueMarkComplete = String(localized: "标记完成")
    static let projectDueMarkIncomplete = String(localized: "标记未完成")

    // Project Invite
    static let projectInviteAccept = String(localized: "接受")
    static let projectInviteReject = String(localized: "拒绝")
    static func projectInviteFrom(_ name: String) -> String {
        String(localized: "\(name) 邀请你加入")
    }
    static let projectNoInvites = String(localized: "暂无项目邀请")

    // MARK: - Quick Meeting
    static let meetingStart = String(localized: "发起会议")
    static let meetingJoin = String(localized: "加入会议")
    static let meetingEnd = String(localized: "结束会议")
    static let meetingInProgress = String(localized: "会议进行中")
    static let meetingLinkPlaceholder = String(localized: "粘贴会议链接...")
    static let meetingStartDesc = String(localized: "粘贴会议链接，队友可以一键加入")
    static let meetingEndConfirm = String(localized: "确认结束会议？")
    static let meetingEndWarning = String(localized: "所有成员将无法再通过此链接加入")
    static let meetingOtherPlatform = String(localized: "其他平台")
    static func meetingStartedBy(_ name: String) -> String {
        String(localized: "\(name) 发起了会议")
    }
    static let meetingLive = String(localized: "LIVE")
    static let meetingPaste = String(localized: "从剪贴板粘贴")

    // MARK: - UX Improvements
    static let confirmDeleteArchivedGoal = String(localized: "确认删除已归档目标")
    static let deleteArchivedGoalWarning = String(localized: "该目标的所有打卡记录将被永久删除，无法恢复")
    static let networkErrorToast = String(localized: "操作失败，请检查网络连接")
    static let removeFriendConfirm = String(localized: "确认删除好友")
    static let removeFriendWarning = String(localized: "删除好友后需要重新添加")
    static let checkInSuccessToast = String(localized: "打卡成功！继续保持 💪")
    static let rejectRequestConfirm = String(localized: "确认拒绝好友请求")
    static let rejectRequestWarning = String(localized: "拒绝后该请求将被移除")
    static let leaveProjectConfirm = String(localized: "确认退出项目")
    static let deleteProjectDueConfirm = String(localized: "确认删除该任务")
    static let deleteProjectDueWarning = String(localized: "删除后无法恢复")
    static let loadFailedRetry = String(localized: "加载失败，下拉刷新重试")
    static let operationSuccess = String(localized: "操作成功")
    static let buildNumber = String(localized: "构建号")

    // MARK: - UX Improvements Round 2
    static let confirmDeleteEvent = String(localized: "确认删除事件")
    static let deleteEventWarning = String(localized: "删除后倒计时事件将被永久移除")
    static let profileSaved = String(localized: "资料已保存")
    static let friendRequestAlreadySent = String(localized: "已发送过好友请求，请勿重复发送")
    static let undoAction = String(localized: "撤销")
    static let deadlineUncompleted = String(localized: "已取消完成")
    static let goalArchivedToast = String(localized: "目标已归档")
    static let unsavedChangesTitle = String(localized: "未保存的更改")
    static let unsavedChangesMessage = String(localized: "你有未保存的更改，确定要离开吗？")
    static let discardChanges = String(localized: "放弃更改")
    static let continueEditing = String(localized: "继续编辑")
    static let codeCopied = String(localized: "已复制到剪贴板")
    static let locationSearchTimeout = String(localized: "搜索超时，请重试")
    static func eventTitleCount(_ current: Int, _ max: Int) -> String {
        "\(current)/\(max)"
    }
    static let countdownComplete = String(localized: "🎉 倒计时完成！")
    static func dlTimeRemaining(_ time: String) -> String {
        String(localized: "\(time) 后")
    }

    // MARK: - Project Activity Timeline
    static let projectTimeline = String(localized: "项目动态")
    static let projectNoActivity = String(localized: "暂无动态")
    static let projectNoActivityDesc = String(localized: "项目活动将显示在这里")

    static func activityMemberJoined(_ name: String) -> String {
        String(localized: "\(name) 加入了项目")
    }
    static func activityMemberLeft(_ name: String) -> String {
        String(localized: "\(name) 退出了项目")
    }
    static func activityDueCreated(_ name: String, _ detail: String) -> String {
        String(localized: "\(name) 创建了任务「\(detail)」")
    }
    static func activityDueCompleted(_ name: String, _ detail: String) -> String {
        String(localized: "\(name) 完成了任务「\(detail)」")
    }
    static func activityDueUncompleted(_ name: String, _ detail: String) -> String {
        String(localized: "\(name) 取消完成「\(detail)」")
    }
    static func activityDueAssigned(_ name: String, _ detail: String) -> String {
        String(localized: "\(name) 分配了任务「\(detail)」")
    }
    static func activityDueDeleted(_ name: String, _ detail: String) -> String {
        String(localized: "\(name) 删除了任务「\(detail)」")
    }
    static func activityProjectCreated(_ name: String) -> String {
        String(localized: "\(name) 创建了项目")
    }
    static func activityMeetingStarted(_ name: String) -> String {
        String(localized: "\(name) 发起了会议")
    }
    static func activityMeetingEnded(_ name: String) -> String {
        String(localized: "\(name) 结束了会议")
    }

    // Stats
    static func projectDueStats(_ completed: Int, _ total: Int) -> String {
        String(localized: "\(completed)/\(total) 已完成")
    }
    static func projectNextDeadline(_ days: Int) -> String {
        if days == 0 { return String(localized: "今天有截止任务") }
        if days < 0 { return String(localized: "有逾期任务") }
        return String(localized: "下个截止：\(days) 天后")
    }

    // MARK: - Todo
    static let todoTitle = String(localized: "待办")
    static let todoAdd = String(localized: "添加待办")
    static let todoEdit = String(localized: "编辑待办")
    static let todoDelete = String(localized: "删除待办")
    static let todoDeleteConfirm = String(localized: "确认删除该待办？")
    static let todoEmpty = String(localized: "还没有待办事项")
    static let todoEmptyDesc = String(localized: "添加你的第一个待办，开始高效管理任务")
    static let todoAllDone = String(localized: "全部完成！")
    static let todoTitleField = String(localized: "待办标题")
    static let todoTitlePlaceholder = String(localized: "输入待办内容...")
    static let todoNote = String(localized: "备注")
    static let todoNotePlaceholder = String(localized: "添加备注（可选）")
    static let todoClearCompleted = String(localized: "清除已完成")
    static let todoClearCompletedTitle = String(localized: "清除已完成待办")
    static let todoClearCompletedConfirm = String(localized: "全部清除")
    static func todoClearCompletedMessage(_ count: Int) -> String {
        String(localized: "确定要删除 \(count) 条已完成的待办吗？此操作不可撤销。")
    }
    static func todoMoreCompleted(_ count: Int) -> String {
        String(localized: "还有 \(count) 条已完成的待办未显示")
    }
    static func todoCompleted(_ count: Int) -> String {
        String(localized: "已完成（\(count)）")
    }

    // MARK: - Focus Timer
    static let focusTitle = String(localized: "专注")
    static let focusStart = String(localized: "开始专注")
    static let focusPause = String(localized: "暂停")
    static let focusResume = String(localized: "继续")
    static let focusGiveUpTitle = String(localized: "放弃本次专注？")
    static let focusGiveUpConfirm = String(localized: "放弃")
    static let focusGiveUpMessage = String(localized: "当前专注记录将不会被保存。")
    static let focusInProgress = String(localized: "专注中...")
    static let focusDuration = String(localized: "专注时长（分钟）")
    static let focusToday = String(localized: "今日")
    static let focusTotal = String(localized: "累计")
    static let focusSessions = String(localized: "次数")
    static let focusTime = String(localized: "专注")
    static let focusHistory = String(localized: "专注记录")
    static let focusNoHistory = String(localized: "还没有专注记录")
    static func focusMinutes(_ mins: Int) -> String {
        String(localized: "\(mins) 分钟")
    }
    static let focusComplete = String(localized: "专注完成！")
    static func focusCompleteDesc(_ mins: Int) -> String {
        String(localized: "你刚刚完成了 \(mins) 分钟的专注，继续保持！")
    }

    // MARK: - Focus Challenge
    static let focusChallenge = String(localized: "专注挑战")
    static let focusChallengeDesc = String(localized: "本月累计专注满 30 小时可免费获得 3 个月 Pro")
    static let focusChallengeReward = String(localized: "3 个月 Pro")
    static let focusChallengeDeadline = String(localized: "6/30 截止")
    static let focusChallengeEnded = String(localized: "活动已结束")
    static let focusChallengeForegroundNote = String(localized: "仅计入前台专注时间")
    static func focusChallengeRemaining(_ hours: String) -> String {
        String(localized: "还差 \(hours) 小时")
    }
    static let focusChallengeCompleted = String(localized: "本月挑战已完成")
    static func focusChallengeRewardExpiry(_ date: String) -> String {
        String(localized: "Pro 有效期至 \(date)")
    }
    static let focusChallengeUnlocked = String(localized: "恭喜！你获得了 3 个月 Pro 奖励！")

    // MARK: - Nudge (拍一拍)
    static let nudge = String(localized: "拍一拍")
    static let nudgeSend = String(localized: "拍一拍 TA")
    static let nudgeSent = String(localized: "已拍")
    static let nudgeAllowToggle = String(localized: "允许拍一拍")
    static let nudgeAllowDesc = String(localized: "开启后朋友可以「拍一拍」你")
    static func nudgeReceived(_ name: String) -> String {
        String(localized: "\(name) 拍了拍你")
    }
    static let nudgeCooldown = String(localized: "休息一下再拍吧")
    static let nudgeDisabledByUser = String(localized: "对方已关闭拍一拍")

    // MARK: - Ring Nudge (响铃拍一拍)
    static let ringNudge = String(localized: "响铃拍一拍")
    static let ringNudgeSend = String(localized: "响铃拍 TA")
    static let ringNudgeSent = String(localized: "已响铃")
    static let ringNudgeAllowToggle = String(localized: "允许 TA 响铃拍我")
    static let ringNudgeAllowDesc = String(localized: "开启后此好友可在你空闲时响铃提醒你")
    static func ringNudgeReceived(_ name: String) -> String {
        String(localized: "\(name) 响铃拍了拍你")
    }
    static func ringNudgeDelivered(_ name: String) -> String {
        String(localized: "\(name) 的手机已响铃")
    }
    static let ringNudgeNotFree = String(localized: "对方当前不在空闲时间")
    static let ringNudgeNoPermission = String(localized: "对方未授权你响铃拍一拍")

    // MARK: - Meetup Session (集合)
    static let meetupCreate = String(localized: "发起集合")
    static let meetupCreateDesc = String(localized: "设定地点和时间，成员可查看模糊位置与到达时间")
    static let meetupTitleLabel = String(localized: "集合标题")
    static let meetupTitlePlaceholder = String(localized: "例如: 图书馆小组讨论")
    static let meetupTimeLabel = String(localized: "集合时间")
    static let meetupPlaceLabel = String(localized: "集合地点")
    static let meetupPlaceSearch = String(localized: "搜索地点...")
    static let meetupActive = String(localized: "集合中")
    static let meetupJoin = String(localized: "加入集合")
    static let meetupEnd = String(localized: "结束集合")
    static let meetupEndConfirm = String(localized: "结束集合？")
    static let meetupEndWarning = String(localized: "结束后所有成员的位置共享将停止")
    static let meetupViewDetails = String(localized: "查看详情")
    static let meetupNavigate = String(localized: "导航前往")
    static let meetupShareLocation = String(localized: "共享我的位置")
    static let meetupShareLocationDesc = String(localized: "关闭后其他成员无法在地图上看到你的大致位置")
    static let meetupMemberLocations = String(localized: "成员位置")
    static let meetupMyETA = String(localized: "我的到达时间")
    static let meetupMemberETAs = String(localized: "成员到达时间")
    static let meetupEtaDriving = String(localized: "驾车")
    static let meetupEtaTransit = String(localized: "公交")
    static let meetupEtaWalking = String(localized: "步行")
    static let meetupLocationHidden = String(localized: "位置已隐藏")
    static let meetupCancelVote = String(localized: "投票取消")
    static let meetupCancelVoted = String(localized: "已投票")
    static let meetupEdit = String(localized: "编辑集合")
    static let meetupSave = String(localized: "保存更改")
    static let meetupCurrentPlace = String(localized: "当前地点")
    static let meetupChangePlace = String(localized: "更换地点")
    static let meetupNoLocations = String(localized: "暂无成员共享位置")
    static let meetupTimeArrived = String(localized: "已到达集合时间")
    static func meetupAttendees(_ count: Int) -> String {
        String(localized: "\(count) 人已加入")
    }
    static func meetupTimeMinutes(_ min: Int) -> String {
        String(localized: "还有 \(min) 分钟")
    }
    static func meetupTimeHours(_ hrs: Int) -> String {
        String(localized: "还有 \(hrs) 小时")
    }
    static func meetupTimeHoursMin(_ hrs: Int, _ min: Int) -> String {
        String(localized: "还有 \(hrs) 小时 \(min) 分钟")
    }
    static func activityMeetupCreated(_ name: String, _ place: String) -> String {
        String(localized: "\(name) 发起了集合: \(place)")
    }
    static func activityMeetupEnded(_ name: String) -> String {
        String(localized: "\(name) 结束了集合")
    }

    // MARK: - Grade Calculator

    static let gradeCalcTitle = String(localized: "成绩计算")
    static let gradeAddCourse = String(localized: "添加课程")
    static let gradeEditCourse = String(localized: "编辑课程")
    static let gradeCourseName = String(localized: "课程名称")
    static let gradeCoursePlaceholder = String(localized: "例如: 线性代数")
    static let gradeTargetGrade = String(localized: "目标成绩")
    static let gradeComponents = String(localized: "成绩组成")
    static let gradeComponentName = String(localized: "项目名称")
    static let gradeComponentPlaceholder = String(localized: "例如: 期中考试")
    static let gradeWeight = String(localized: "权重")
    static let gradeScore = String(localized: "得分")
    static let gradeScoreNotEntered = String(localized: "未录入")
    static let gradeRawScore = String(localized: "原始分")
    static let gradePercentScore = String(localized: "百分比")
    static let gradeCurrentGrade = String(localized: "当前成绩")
    static let gradeNeededScore = String(localized: "剩余项目需得分")
    static let gradeTargetReachable = String(localized: "目标可达")
    static let gradeTargetUnreachable = String(localized: "目标可能无法达到")
    static let gradeAlreadyPassed = String(localized: "已达标")
    static let gradeEmptyTitle = String(localized: "还没有课程")
    static let gradeEmptySubtitle = String(localized: "添加课程，录入成绩\n计算达标所需分数")
    static let gradeArchived = String(localized: "已归档课程")
    static let gradeArchiveCourse = String(localized: "归档课程")
    static let gradeDeleteCourse = String(localized: "删除课程")
    static let gradeDeleteWarning = String(localized: "删除后所有成绩记录将被清除，无法恢复")
    static let gradeConfirmDelete = String(localized: "确认删除")
    static let gradeReactivate = String(localized: "重新激活")
    static let gradeAddComponent = String(localized: "添加项目")
    static let gradeEditScore = String(localized: "编辑分数")
    static let gradeDeleteComponent = String(localized: "删除项目")
    static let gradeWeightError = String(localized: "权重之和必须为 100%")
    static let gradeEffective = String(localized: "有效分数")
    static let gradeFinalNeeded = String(localized: "期末需要")
    static let gradeMaxHint = String(localized: "免费版最多 3 门课程")
    static let gradeFinal = String(localized: "Final")
    static let gradeSetAsFinal = String(localized: "设为 Final")
    static let gradeIsFinal = String(localized: "Final 考试/项目")
    static let gradeWeightWarning = String(localized: "权重合计不等于 100%，成绩计算可能不准确")
    static let gradeWeightDismiss = String(localized: "我知道了")
    static let gradeConfirmedScore = String(localized: "已确定分数")
    static let gradeNoComponents = String(localized: "暂无成绩项目")
    static let gradeTarget = String(localized: "目标")
    static let gradeSaveScore = String(localized: "保存分数")
    static let gradeEnterScore = String(localized: "录入分数")
    static func gradeWeightSum(_ sum: Int) -> String {
        String(localized: "权重合计 \(sum)%")
    }
    static func gradeNeededPercent(_ percent: Int) -> String {
        String(localized: "剩余项目需平均 \(percent)%")
    }

    // MARK: - Settings / About (补漏)
    static let deadline = String(localized: "截止日期效果")
    static let aboutDevRole = String(localized: "开发者 & 设计师")
    static let aboutMadeWith = String(localized: "为留学生用心打造 ❤️")

    // MARK: - Birthday
    static func birthdayGreeting(name: String) -> String {
        String(localized: "生日快乐，\(name)！")
    }
    static let birthdayWish = String(localized: "祝你新的一岁一切顺利！🎉")
    static let birthdayAddOptional = String(localized: "添加生日（可选）")
}
