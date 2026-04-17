const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ============================================================
// 1. New Due Created → Notify project members
// ============================================================
exports.onProjectDueCreated = onDocumentCreated(
  "projects/{projectId}/dues/{dueId}",
  async (event) => {
    const due = event.data.data();
    const projectId = event.params.projectId;

    const projectDoc = await db.collection("projects").doc(projectId).get();
    if (!projectDoc.exists) return;
    const project = projectDoc.data();

    // Notify all members except the creator
    const recipientIds = project.memberIds.filter((uid) => uid !== due.createdBy);
    if (recipientIds.length === 0) return;

    const tokens = await getFCMTokens(recipientIds);
    if (tokens.length === 0) return;

    const message = {
      notification: {
        title: `${project.emoji} ${project.name}`,
        body: `${due.creatorName} 添加了新任务: ${due.emoji} ${due.title}`,
      },
      data: {
        type: "due_created",
        projectId: projectId,
        dueId: event.params.dueId,
      },
    };

    await sendToTokens(tokens, message);
    console.log(`[DueCreated] Notified ${tokens.length} members for ${due.title}`);
  }
);

// ============================================================
// 2. Due Completed → Notify project members
// ============================================================
exports.onProjectDueCompleted = onDocumentUpdated(
  "projects/{projectId}/dues/{dueId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Only trigger when isCompleted changes from false → true
    if (before.isCompleted || !after.isCompleted) return;

    const projectId = event.params.projectId;
    const projectDoc = await db.collection("projects").doc(projectId).get();
    if (!projectDoc.exists) return;
    const project = projectDoc.data();

    // Notify all members except the completer
    const completedBy = after.completedBy;
    const recipientIds = project.memberIds.filter((uid) => uid !== completedBy);
    if (recipientIds.length === 0) return;

    const tokens = await getFCMTokens(recipientIds);
    if (tokens.length === 0) return;

    // Find completer name
    const completerProfile = project.memberProfiles?.find((m) => m.id === completedBy);
    const completerName = completerProfile?.displayName || "Someone";

    const message = {
      notification: {
        title: `${project.emoji} ${project.name}`,
        body: `${completerName} 完成了任务: ${after.emoji} ${after.title} ✅`,
      },
      data: {
        type: "due_completed",
        projectId: projectId,
        dueId: event.params.dueId,
      },
    };

    await sendToTokens(tokens, message);
    console.log(`[DueCompleted] Notified ${tokens.length} members for ${after.title}`);
  }
);

// ============================================================
// 3. Project Invite → Notify invited user
// ============================================================
exports.onProjectInviteSent = onDocumentCreated(
  "users/{userId}/projectInvites/{inviteId}",
  async (event) => {
    const invite = event.data.data();
    const userId = event.params.userId;

    const tokens = await getFCMTokens([userId]);
    if (tokens.length === 0) return;

    const message = {
      notification: {
        title: "项目邀请",
        body: `${invite.inviterName} 邀请你加入 ${invite.projectEmoji} ${invite.projectName}`,
      },
      data: {
        type: "project_invite",
        projectId: invite.projectId,
      },
    };

    await sendToTokens(tokens, message);
    console.log(`[Invite] Notified ${userId.substring(0, 8)}... for ${invite.projectName}`);
  }
);

// ============================================================
// 4. Member Joined → Notify existing members
// ============================================================
exports.onProjectMemberJoined = onDocumentUpdated(
  "projects/{projectId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Detect new member: memberIds array grew
    if (after.memberIds.length <= before.memberIds.length) return;

    const newMemberIds = after.memberIds.filter((uid) => !before.memberIds.includes(uid));
    if (newMemberIds.length === 0) return;

    // Find new member profiles
    const newMembers = after.memberProfiles?.filter((m) => newMemberIds.includes(m.id)) || [];
    const newMemberName = newMembers.map((m) => m.displayName).join(", ") || "New member";

    // Notify existing members (not the new one)
    const existingMemberIds = before.memberIds;
    const tokens = await getFCMTokens(existingMemberIds);
    if (tokens.length === 0) return;

    const message = {
      notification: {
        title: `${after.emoji} ${after.name}`,
        body: `${newMemberName} 加入了项目 🎉`,
      },
      data: {
        type: "member_joined",
        projectId: event.params.projectId,
      },
    };

    await sendToTokens(tokens, message);
    console.log(`[MemberJoined] ${newMemberName} joined ${after.name}`);
  }
);

// ============================================================
// 5. Friend Request → Notify recipient
// ============================================================
exports.onFriendRequestSent = onDocumentCreated(
  "users/{userId}/friendRequests/{requestId}",
  async (event) => {
    const request = event.data.data();
    const userId = event.params.userId;

    const tokens = await getFCMTokens([userId]);
    if (tokens.length === 0) return;

    const message = {
      notification: {
        title: "好友请求",
        body: `${request.fromName} ${request.fromEmoji || ""} 想要添加你为好友`,
      },
      data: {
        type: "friend_request",
      },
    };

    await sendToTokens(tokens, message);
    console.log(`[FriendRequest] Notified ${userId.substring(0, 8)}... from ${request.fromName}`);
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

        let urgency = null;
        let body = null;

        // Overdue
        if (dueDate < now) {
          urgency = "deadline_overdue";
          const daysOverdue = Math.floor((now - dueDate) / (1000 * 60 * 60 * 24));
          body = `${due.emoji} ${due.title} 已逾期 ${daysOverdue} 天！`;
        }
        // Due today
        else if (dueDate < tomorrow) {
          urgency = "deadline_approaching";
          body = `${due.emoji} ${due.title} 今天截止！`;
        }
        // Due within 3 days
        else if (dueDate < in3Days) {
          urgency = "deadline_approaching";
          const daysLeft = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24));
          body = `${due.emoji} ${due.title} 还有 ${daysLeft} 天截止`;
        }

        if (!urgency || !body) continue;

        // Determine who to notify
        let recipientIds;
        if (Array.isArray(due.assignedTo) && due.assignedTo.length > 0) {
          // Notify all assigned people
          recipientIds = due.assignedTo;
        } else if (typeof due.assignedTo === 'string') {
          // Legacy single-assign format
          recipientIds = [due.assignedTo];
        } else {
          // Notify all members
          recipientIds = project.memberIds;
        }

        const tokens = await getFCMTokens(recipientIds);
        if (tokens.length === 0) continue;

        const message = {
          notification: {
            title: `${project.emoji} ${project.name}`,
            body: body,
          },
          data: {
            type: urgency,
            projectId: projectDoc.id,
            dueId: dueDoc.id,
          },
        };

        await sendToTokens(tokens, message);
        notificationCount++;
      }
    }

    console.log(`[Scheduler] Sent ${notificationCount} deadline reminders`);
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
  if (tokens.length === 0) return;

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
          console.log(`[FCM] Removing invalid token: ${tokens[idx].substring(0, 20)}...`);
          // Find user with this token and remove it
          removeInvalidToken(tokens[idx]);
        }
      }
    });

    const successCount = response.responses.filter((r) => r.success).length;
    console.log(`[FCM] Sent ${successCount}/${tokens.length} messages`);
  } catch (error) {
    console.error("[FCM] sendEach error:", error);
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
