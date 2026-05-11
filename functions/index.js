const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ============================================================
// Push notification i18n
// ============================================================
//
// iOS app writes `locale` (one of zh-Hans / zh-Hant / en / ja / ko) to
// users/{uid} alongside the FCM token. We read the receiver's locale
// before sending and localize title + body accordingly.
//
// Source language is zh-Hans — any unknown locale (or missing field on
// older clients that haven't refreshed their token since the i18n rollout)
// falls back to zh-Hans, so existing users continue to see Chinese until
// they next launch the app and a fresh token write fills the field in.
//
// Body strings can be a string or a function(params)→string for runtime
// interpolation. Functions accept `{emoji, name, ...}` so call-sites
// pass concrete values when invoking `localize(key, locale, params)`.
const I18N = {
  // Project due notifications
  due_created_body: {
    "zh-Hans": (p) => `${p.creator} 添加了新任务: ${p.emoji} ${p.title}`,
    "zh-Hant": (p) => `${p.creator} 新增了任務：${p.emoji} ${p.title}`,
    "en":      (p) => `${p.creator} added a task: ${p.emoji} ${p.title}`,
    "ja":      (p) => `${p.creator} さんが新しいタスクを追加: ${p.emoji} ${p.title}`,
    "ko":      (p) => `${p.creator}님이 새 작업을 추가했습니다: ${p.emoji} ${p.title}`,
  },
  due_completed_body: {
    "zh-Hans": (p) => `${p.completer} 完成了任务: ${p.emoji} ${p.title} ✅`,
    "zh-Hant": (p) => `${p.completer} 完成了任務:${p.emoji} ${p.title} ✅`,
    "en":      (p) => `${p.completer} completed: ${p.emoji} ${p.title} ✅`,
    "ja":      (p) => `${p.completer} さんがタスクを完了: ${p.emoji} ${p.title} ✅`,
    "ko":      (p) => `${p.completer}님이 작업을 완료했습니다: ${p.emoji} ${p.title} ✅`,
  },
  due_overdue_body: {
    "zh-Hans": (p) => `${p.emoji} ${p.title} 已逾期 ${p.days} 天!`,
    "zh-Hant": (p) => `${p.emoji} ${p.title} 已逾期 ${p.days} 天!`,
    "en":      (p) => `${p.emoji} ${p.title} is ${p.days} day(s) overdue!`,
    "ja":      (p) => `${p.emoji} ${p.title} は${p.days}日遅れています!`,
    "ko":      (p) => `${p.emoji} ${p.title} 이(가) ${p.days}일 지났습니다!`,
  },
  due_today_body: {
    "zh-Hans": (p) => `${p.emoji} ${p.title} 今天截止!`,
    "zh-Hant": (p) => `${p.emoji} ${p.title} 今天到期!`,
    "en":      (p) => `${p.emoji} ${p.title} is due today!`,
    "ja":      (p) => `${p.emoji} ${p.title} は本日締切です!`,
    "ko":      (p) => `${p.emoji} ${p.title} 오늘이 마감일입니다!`,
  },
  due_approaching_body: {
    "zh-Hans": (p) => `${p.emoji} ${p.title} 还有 ${p.days} 天截止`,
    "zh-Hant": (p) => `${p.emoji} ${p.title} 還有 ${p.days} 天到期`,
    "en":      (p) => `${p.emoji} ${p.title} is due in ${p.days} day(s)`,
    "ja":      (p) => `${p.emoji} ${p.title} はあと${p.days}日`,
    "ko":      (p) => `${p.emoji} ${p.title} 마감까지 ${p.days}일`,
  },

  // Invites & joins
  project_invite_title: {
    "zh-Hans": "项目邀请",
    "zh-Hant": "專案邀請",
    "en":      "Project invite",
    "ja":      "プロジェクト招待",
    "ko":      "프로젝트 초대",
  },
  project_invite_body: {
    "zh-Hans": (p) => `${p.inviter} 邀请你加入 ${p.emoji} ${p.project}`,
    "zh-Hant": (p) => `${p.inviter} 邀請你加入 ${p.emoji} ${p.project}`,
    "en":      (p) => `${p.inviter} invited you to join ${p.emoji} ${p.project}`,
    "ja":      (p) => `${p.inviter} さんが ${p.emoji} ${p.project} に招待しました`,
    "ko":      (p) => `${p.inviter}님이 ${p.emoji} ${p.project}에 초대했습니다`,
  },
  member_joined_body: {
    "zh-Hans": (p) => `${p.name} 加入了项目 🎉`,
    "zh-Hant": (p) => `${p.name} 加入了專案 🎉`,
    "en":      (p) => `${p.name} joined the project 🎉`,
    "ja":      (p) => `${p.name} さんがプロジェクトに参加 🎉`,
    "ko":      (p) => `${p.name}님이 프로젝트에 참여했습니다 🎉`,
  },

  // Friend request
  friend_request_title: {
    "zh-Hans": "好友请求",
    "zh-Hant": "好友請求",
    "en":      "Friend request",
    "ja":      "友達リクエスト",
    "ko":      "친구 요청",
  },
  friend_request_body: {
    "zh-Hans": (p) => `${p.name} ${p.emoji} 想要添加你为好友`,
    "zh-Hant": (p) => `${p.name} ${p.emoji} 想要加你為好友`,
    "en":      (p) => `${p.name} ${p.emoji} wants to add you as a friend`,
    "ja":      (p) => `${p.name} ${p.emoji} さんから友達申請が届きました`,
    "ko":      (p) => `${p.name} ${p.emoji}님이 친구 요청을 보냈습니다`,
  },

  // Nudge (pat)
  nudge_received_title: {
    "zh-Hans": "拍一拍 👋",
    "zh-Hant": "拍一拍 👋",
    "en":      "Nudge 👋",
    "ja":      "ナッジ 👋",
    "ko":      "찌르기 👋",
  },
  nudge_received_body: {
    "zh-Hans": (p) => `${p.emoji} ${p.name} 拍了拍你`,
    "zh-Hant": (p) => `${p.emoji} ${p.name} 拍了拍你`,
    "en":      (p) => `${p.emoji} ${p.name} nudged you`,
    "ja":      (p) => `${p.emoji} ${p.name} さんがあなたをナッジしました`,
    "ko":      (p) => `${p.emoji} ${p.name}님이 당신을 찔렀어요`,
  },
  nudge_delivered_title: {
    "zh-Hans": "拍一拍已送达 ✅",
    "zh-Hant": "拍一拍已送達 ✅",
    "en":      "Nudge delivered ✅",
    "ja":      "ナッジが届きました ✅",
    "ko":      "찌르기 전달됨 ✅",
  },
  nudge_delivered_body: {
    "zh-Hans": (p) => `${p.emoji} ${p.name} 已收到你的拍一拍`,
    "zh-Hant": (p) => `${p.emoji} ${p.name} 已收到你的拍一拍`,
    "en":      (p) => `${p.emoji} ${p.name} received your nudge`,
    "ja":      (p) => `${p.emoji} ${p.name} さんがあなたのナッジを受け取りました`,
    "ko":      (p) => `${p.emoji} ${p.name}님이 찌르기를 받았습니다`,
  },

  // Ring nudge
  ring_nudge_received_title: {
    "zh-Hans": "响铃拍一拍 🔔",
    "zh-Hant": "響鈴拍一拍 🔔",
    "en":      "Ring nudge 🔔",
    "ja":      "リングナッジ 🔔",
    "ko":      "벨 찌르기 🔔",
  },
  ring_nudge_received_body: {
    "zh-Hans": (p) => `${p.emoji} ${p.name} 响铃拍了拍你!`,
    "zh-Hant": (p) => `${p.emoji} ${p.name} 響鈴拍了拍你!`,
    "en":      (p) => `${p.emoji} ${p.name} ring-nudged you!`,
    "ja":      (p) => `${p.emoji} ${p.name} さんがあなたを呼んでいます!`,
    "ko":      (p) => `${p.emoji} ${p.name}님이 벨로 찔렀습니다!`,
  },
  ring_nudge_delivered_title: {
    "zh-Hans": "响铃已送达 🔔",
    "zh-Hant": "響鈴已送達 🔔",
    "en":      "Ring delivered 🔔",
    "ja":      "リングが届きました 🔔",
    "ko":      "벨 전달됨 🔔",
  },
  ring_nudge_delivered_body: {
    "zh-Hans": (p) => `${p.name} 的手机已响铃`,
    "zh-Hant": (p) => `${p.name} 的手機已響鈴`,
    "en":      (p) => `${p.name}'s phone rang`,
    "ja":      (p) => `${p.name} さんの電話が鳴りました`,
    "ko":      (p) => `${p.name}님의 전화벨이 울렸습니다`,
  },

  // Generic fallback display name. Used inside other templates when the
  // receiver's displayName is missing, so we don't leak Chinese "对方"
  // into an English / Japanese / Korean sender's notification body.
  friend_fallback: {
    "zh-Hans": "对方",
    "zh-Hant": "對方",
    "en":      "Your friend",
    "ja":      "相手",
    "ko":      "상대방",
  },
};

/**
 * Pick the localized string from the I18N table. Falls back to zh-Hans
 * (the source language) if the receiver's locale isn't supported or the
 * key is missing.
 */
function localize(key, locale, params) {
  const table = I18N[key];
  if (!table) {
    console.warn(`[i18n] missing key: ${key}`);
    return "";
  }
  const value = table[locale] || table["zh-Hans"];
  return typeof value === "function" ? value(params || {}) : value;
}

/**
 * Sanitize a user-supplied string for inclusion in a push notification.
 * Strips control characters and clamps the length so a malicious or
 * malformed client write can't blow up the notification payload or
 * inject newlines / null bytes into the body. Returns the fallback if
 * the input is missing, empty after trimming, or wasn't a string.
 */
function safeStr(value, fallback = "", maxLen = 80) {
  if (typeof value !== "string") return fallback;
  // Strip Unicode control characters (newlines, null bytes, etc.).
  const cleaned = value.replace(/\p{Cc}/gu, "").trim();
  if (cleaned.length === 0) return fallback;
  return cleaned.length > maxLen ? cleaned.slice(0, maxLen) + "…" : cleaned;
}

/**
 * Read a single user's `locale` field from Firestore. Cached per Cloud
 * Function invocation via passed-in doc when caller already fetched the
 * user. Returns "zh-Hans" if the field is missing.
 */
function localeFromDoc(docData) {
  if (!docData) return "zh-Hans";
  return docData.locale || "zh-Hans";
}

async function fetchLocale(uid) {
  try {
    const doc = await db.collection("users").doc(uid).get();
    return localeFromDoc(doc.exists ? doc.data() : null);
  } catch {
    return "zh-Hans";
  }
}

/**
 * Batch-fetch FCM tokens AND locale per UID in a single Firestore round.
 * Returns `[{uid, token, locale}]`. Used by `sendLocalizedNotification` to
 * group recipients by locale before sending FCM.
 */
async function getRecipients(uids) {
  const recipients = [];
  for (let i = 0; i < uids.length; i += 10) {
    const batch = uids.slice(i, i + 10);
    const snapshot = await db.collection("users")
      .where("__name__", "in", batch).get();
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const token = data.fcmToken;
      if (token) {
        recipients.push({
          uid: doc.id,
          token,
          locale: data.locale || "zh-Hans",
        });
      }
    }
  }
  return recipients;
}

/**
 * Send a localized push to a list of UIDs. Splits the recipients by their
 * preferred locale and sends one FCM batch per group with that locale's
 * title and body strings from the I18N table.
 *
 * `title` is either a fixed string (for user-content like project names
 * which aren't translated) OR null in which case `titleKey` is looked up
 * in I18N. `bodyKey` is always looked up in I18N. Both `params` and
 * `dataPayload` are forwarded as-is to all groups.
 */
async function sendLocalizedNotification({
  uids, title, titleKey, bodyKey, params, dataPayload, apnsOverrides,
}) {
  const recipients = await getRecipients(uids);
  if (recipients.length === 0) return 0;

  // Group recipients by locale
  const byLocale = {};
  for (const r of recipients) {
    if (!byLocale[r.locale]) byLocale[r.locale] = [];
    byLocale[r.locale].push(r.token);
  }

  let totalSent = 0;
  for (const [locale, tokens] of Object.entries(byLocale)) {
    const localizedTitle = title != null
      ? title
      : localize(titleKey, locale, params);
    const message = {
      notification: {
        title: localizedTitle,
        body: localize(bodyKey, locale, params),
      },
      data: dataPayload || {},
      ...(apnsOverrides ? { apns: apnsOverrides } : {}),
    };
    totalSent += await sendToTokens(tokens, message);
  }
  return totalSent;
}

// ============================================================
// 1. New Due Created → Notify project members
// ============================================================
exports.onProjectDueCreated = onDocumentCreated(
  "projects/{projectId}/dues/{dueId}",
  async (event) => {
    const due = event.data?.data();
    if (!due) return;
    const projectId = event.params.projectId;

    const projectDoc = await db.collection("projects").doc(projectId).get();
    if (!projectDoc.exists) return;
    const project = projectDoc.data();
    if (!Array.isArray(project.memberIds)) return;

    // Notify all members except the creator
    const recipientIds = project.memberIds.filter((uid) => uid !== due.createdBy);
    if (recipientIds.length === 0) return;

    const sent = await sendLocalizedNotification({
      uids: recipientIds,
      title: `${safeStr(project.emoji, "")} ${safeStr(project.name, "Project")}`.trim(),
      bodyKey: "due_created_body",
      params: {
        creator: safeStr(due.creatorName, "Someone", 40),
        emoji: safeStr(due.emoji, "", 8),
        title: safeStr(due.title, "Untitled", 60),
      },
      dataPayload: {
        type: "due_created",
        projectId: projectId,
        dueId: event.params.dueId,
      },
    });
    console.log(`[DueCreated] Notified ${sent} members`);
  }
);

// ============================================================
// 2. Due Completed → Notify project members
// ============================================================
exports.onProjectDueCompleted = onDocumentUpdated(
  "projects/{projectId}/dues/{dueId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    // Only trigger when isCompleted changes from false → true
    if (before.isCompleted || !after.isCompleted) return;

    const projectId = event.params.projectId;
    const projectDoc = await db.collection("projects").doc(projectId).get();
    if (!projectDoc.exists) return;
    const project = projectDoc.data();
    if (!Array.isArray(project.memberIds)) return;

    // Notify all members except the completer
    const completedBy = after.completedBy;
    const recipientIds = project.memberIds.filter((uid) => uid !== completedBy);
    if (recipientIds.length === 0) return;

    // Find completer name
    const completerProfile = (project.memberProfiles || []).find((m) => m && m.id === completedBy);
    const completerName = safeStr(completerProfile?.displayName, "Someone", 40);

    const sent = await sendLocalizedNotification({
      uids: recipientIds,
      title: `${safeStr(project.emoji, "")} ${safeStr(project.name, "Project")}`.trim(),
      bodyKey: "due_completed_body",
      params: {
        completer: completerName,
        emoji: safeStr(after.emoji, "", 8),
        title: safeStr(after.title, "Untitled", 60),
      },
      dataPayload: {
        type: "due_completed",
        projectId: projectId,
        dueId: event.params.dueId,
      },
    });
    console.log(`[DueCompleted] Notified ${sent} members`);
  }
);

// ============================================================
// 3. Project Invite → Notify invited user
// ============================================================
exports.onProjectInviteSent = onDocumentCreated(
  "users/{userId}/projectInvites/{inviteId}",
  async (event) => {
    const invite = event.data?.data();
    if (!invite) return;
    const userId = event.params.userId;

    await sendLocalizedNotification({
      uids: [userId],
      titleKey: "project_invite_title",
      bodyKey: "project_invite_body",
      params: {
        inviter: safeStr(invite.inviterName, "Someone", 40),
        emoji: safeStr(invite.projectEmoji, "", 8),
        project: safeStr(invite.projectName, "a project", 60),
      },
      dataPayload: {
        type: "project_invite",
        projectId: invite.projectId || "",
      },
    });
    console.log(`[Invite] Notified user`);
  }
);

// ============================================================
// 4. Member Joined → Notify existing members
// ============================================================
exports.onProjectMemberJoined = onDocumentUpdated(
  "projects/{projectId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;
    if (!Array.isArray(before.memberIds) || !Array.isArray(after.memberIds)) return;

    // Detect new member: memberIds array grew
    if (after.memberIds.length <= before.memberIds.length) return;

    const newMemberIds = after.memberIds.filter((uid) => !before.memberIds.includes(uid));
    if (newMemberIds.length === 0) return;

    // Find new member profiles
    const newMembers = (after.memberProfiles || []).filter((m) => m && newMemberIds.includes(m.id));
    const newMemberName = safeStr(
      newMembers.map((m) => m.displayName).filter(Boolean).join(", "),
      "New member",
      60
    );

    // Notify existing members (not the new one)
    const existingMemberIds = before.memberIds;
    if (existingMemberIds.length === 0) return;

    await sendLocalizedNotification({
      uids: existingMemberIds,
      title: `${safeStr(after.emoji, "")} ${safeStr(after.name, "Project")}`.trim(),
      bodyKey: "member_joined_body",
      params: { name: newMemberName },
      dataPayload: {
        type: "member_joined",
        projectId: event.params.projectId,
      },
    });
    console.log(`[MemberJoined] new member joined project`);
  }
);

// ============================================================
// 5. Friend Request → Notify recipient
// ============================================================
exports.onFriendRequestSent = onDocumentCreated(
  "users/{userId}/friendRequests/{requestId}",
  async (event) => {
    const request = event.data?.data();
    if (!request) return;
    const userId = event.params.userId;

    await sendLocalizedNotification({
      uids: [userId],
      titleKey: "friend_request_title",
      bodyKey: "friend_request_body",
      params: {
        name: safeStr(request.fromName, "Someone", 40),
        emoji: safeStr(request.fromEmoji, "", 8),
      },
      dataPayload: {
        type: "friend_request",
      },
    });
    console.log(`[FriendRequest] Notified user`);
  }
);

// ============================================================
// 6. Scheduled: Deadline Approaching (every day at 9:00 AM UTC)
// ============================================================
exports.scheduledDeadlineReminder = onSchedule(
  {
    schedule: "every day 09:00",
    timeZone: "UTC",
  },
  async () => {
    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const in3Days = new Date(now);
    in3Days.setDate(in3Days.getDate() + 3);

    // Get all active projects
    const projectsSnapshot = await db
      .collection("projects")
      .where("isArchived", "==", false)
      .get();

    let notificationCount = 0;

    for (const projectDoc of projectsSnapshot.docs) {
      const project = projectDoc.data();

      // Get incomplete dues
      const duesSnapshot = await db
        .collection("projects")
        .doc(projectDoc.id)
        .collection("dues")
        .where("isCompleted", "==", false)
        .get();

      for (const dueDoc of duesSnapshot.docs) {
        const due = dueDoc.data();
        const dueDate = due.dueDate.toDate();

        // Pick the right localized body key + days param based on urgency.
        // The string itself is materialized per-receiver inside
        // sendLocalizedNotification so each member gets their own locale.
        let urgency = null;
        let bodyKey = null;
        let days = 0;

        if (dueDate < now) {
          urgency = "deadline_overdue";
          bodyKey = "due_overdue_body";
          days = Math.floor((now - dueDate) / (1000 * 60 * 60 * 24));
        } else if (dueDate < tomorrow) {
          urgency = "deadline_approaching";
          bodyKey = "due_today_body";
        } else if (dueDate < in3Days) {
          urgency = "deadline_approaching";
          bodyKey = "due_approaching_body";
          days = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24));
        }

        if (!urgency || !bodyKey) continue;

        // Determine who to notify
        let recipientIds;
        if (Array.isArray(due.assignedTo) && due.assignedTo.length > 0) {
          // Notify all assigned people
          recipientIds = due.assignedTo;
        } else if (typeof due.assignedTo === "string") {
          // Legacy single-assign format
          recipientIds = [due.assignedTo];
        } else {
          // Notify all members
          recipientIds = project.memberIds;
        }
        if (!recipientIds || recipientIds.length === 0) continue;

        const sent = await sendLocalizedNotification({
          uids: recipientIds,
          title: `${safeStr(project.emoji, "")} ${safeStr(project.name, "Project")}`.trim(),
          bodyKey: bodyKey,
          params: {
            emoji: safeStr(due.emoji, "", 8),
            title: safeStr(due.title, "Untitled", 60),
            days: days,
          },
          dataPayload: {
            type: urgency,
            projectId: projectDoc.id,
            dueId: dueDoc.id,
          },
        });
        if (sent > 0) notificationCount++;
      }
    }

    console.log(`[Scheduler] Sent ${notificationCount} deadline reminders`);
  }
);

// ============================================================
// 7. Nudge (拍一拍) → Notify receiver + confirm to sender
// ============================================================
exports.onNudgeSent = onDocumentCreated(
  "users/{receiverUid}/nudges/{nudgeId}",
  async (event) => {
    const nudge = event.data?.data();
    if (!nudge) return;
    const receiverUid = event.params.receiverUid;
    const senderUid = safeStr(nudge.fromUid, "", 64);
    if (!senderUid) return;
    const senderName = safeStr(nudge.fromName, "Someone", 40);
    const senderEmoji = safeStr(nudge.fromEmoji, "👋", 8);

    // 1) Send nudge notification to receiver in their preferred locale.
    const receiverDoc = await db.collection("users").doc(receiverUid).get();
    const receiverData = receiverDoc.exists ? receiverDoc.data() : null;
    const receiverLocale = localeFromDoc(receiverData);
    const receiverTokens = await getFCMTokens([receiverUid]);
    if (receiverTokens.length > 0) {
      const receiverMessage = {
        notification: {
          title: localize("nudge_received_title", receiverLocale),
          body: localize("nudge_received_body", receiverLocale, {
            emoji: senderEmoji, name: senderName,
          }),
        },
        data: {
          type: "nudge_received",
        },
      };
      const result = await sendToTokens(receiverTokens, receiverMessage);

      // 2) If successfully delivered, confirm to sender in THEIR locale
      // (likely different from receiver's — eg sender ja, receiver zh).
      if (result > 0) {
        const senderLocale = await fetchLocale(senderUid);
        const receiverName = safeStr(receiverData?.displayName, "", 40)
          || localize("friend_fallback", senderLocale);
        const receiverEmoji = safeStr(receiverData?.avatarEmoji, "", 8);

        const senderTokens = await getFCMTokens([senderUid]);
        if (senderTokens.length > 0) {
          const confirmMessage = {
            notification: {
              title: localize("nudge_delivered_title", senderLocale),
              body: localize("nudge_delivered_body", senderLocale, {
                emoji: receiverEmoji, name: receiverName,
              }),
            },
            data: {
              type: "nudge_delivered",
            },
          };
          await sendToTokens(senderTokens, confirmMessage);
        }
      }
    }

    console.log(`[Nudge] delivered`);
  }
);

// ============================================================
// 8. Ring Nudge (响铃拍一拍) → Critical push to receiver + confirm to sender
// ============================================================
exports.onRingNudgeSent = onDocumentCreated(
  "users/{receiverUid}/ringNudges/{nudgeId}",
  async (event) => {
    const nudge = event.data?.data();
    if (!nudge) return;
    const receiverUid = event.params.receiverUid;
    const senderUid = safeStr(nudge.fromUid, "", 64);
    if (!senderUid) return;
    const senderName = safeStr(nudge.fromName, "Someone", 40);
    const senderEmoji = safeStr(nudge.fromEmoji, "🔔", 8);

    // 1) Send critical notification to receiver in their locale.
    const receiverDoc = await db.collection("users").doc(receiverUid).get();
    const receiverData = receiverDoc.exists ? receiverDoc.data() : null;
    const receiverLocale = localeFromDoc(receiverData);
    const receiverTokens = await getFCMTokens([receiverUid]);
    if (receiverTokens.length > 0) {
      const receiverMessage = {
        notification: {
          title: localize("ring_nudge_received_title", receiverLocale),
          body: localize("ring_nudge_received_body", receiverLocale, {
            emoji: senderEmoji, name: senderName,
          }),
        },
        data: {
          type: "ring_nudge_received",
        },
        apns: {
          payload: {
            aps: {
              sound: {
                critical: true,
                name: "default",
                volume: 1.0,
              },
            },
          },
        },
      };
      const result = await sendToTokens(receiverTokens, receiverMessage);

      // 2) If successfully delivered, confirm to sender in THEIR locale.
      if (result > 0) {
        const senderLocale = await fetchLocale(senderUid);
        const receiverName = safeStr(receiverData?.displayName, "", 40)
          || localize("friend_fallback", senderLocale);

        const senderTokens = await getFCMTokens([senderUid]);
        if (senderTokens.length > 0) {
          const confirmMessage = {
            notification: {
              title: localize("ring_nudge_delivered_title", senderLocale),
              body: localize("ring_nudge_delivered_body", senderLocale, {
                name: receiverName,
              }),
            },
            data: {
              type: "ring_nudge_delivered",
            },
          };
          await sendToTokens(senderTokens, confirmMessage);
        }
      }
    }

    console.log(`[RingNudge] delivered`);
  }
);

// ============================================================
// Helper: Get FCM tokens for UIDs
// ============================================================
async function getFCMTokens(uids) {
  const tokens = [];
  // Batch read in groups of 10 (Firestore IN query limit)
  for (let i = 0; i < uids.length; i += 10) {
    const batch = uids.slice(i, i + 10);
    const snapshot = await db
      .collection("users")
      .where("__name__", "in", batch)
      .get();

    for (const doc of snapshot.docs) {
      const token = doc.data().fcmToken;
      if (token) {
        tokens.push(token);
      }
    }
  }
  return tokens;
}

// ============================================================
// Helper: Send FCM to multiple tokens (handles invalid tokens)
// ============================================================
async function sendToTokens(tokens, messageTemplate) {
  if (tokens.length === 0) return 0;

  const messages = tokens.map((token) => ({
    ...messageTemplate,
    token: token,
  }));

  try {
    const response = await getMessaging().sendEach(messages);

    // Clean up invalid tokens
    response.responses.forEach((resp, idx) => {
      if (resp.error) {
        const errorCode = resp.error.code;
        if (
          errorCode === "messaging/invalid-registration-token" ||
          errorCode === "messaging/registration-token-not-registered"
        ) {
          // Don't log token prefix — FCM tokens are sensitive and a
          // 20-char prefix is enough material to aid token enumeration
          // attacks if the logs are ever exposed.
          console.log(`[FCM] Removing invalid token`);
          removeInvalidToken(tokens[idx]);
        }
      }
    });

    const successCount = response.responses.filter((r) => r.success).length;
    console.log(`[FCM] Sent ${successCount}/${tokens.length} messages`);
    return successCount;
  } catch (error) {
    console.error("[FCM] sendEach error:", error);
    return 0;
  }
}

// ============================================================
// Helper: Remove invalid FCM token from Firestore
// ============================================================
async function removeInvalidToken(token) {
  try {
    const snapshot = await db
      .collection("users")
      .where("fcmToken", "==", token)
      .limit(1)
      .get();

    if (!snapshot.empty) {
      await snapshot.docs[0].ref.update({
        fcmToken: require("firebase-admin/firestore").FieldValue.delete(),
        fcmTokenUpdatedAt: require("firebase-admin/firestore").FieldValue.delete(),
      });
    }
  } catch (error) {
    console.error("[FCM] removeInvalidToken error:", error);
  }
}
