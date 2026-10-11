const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { generateTemporaryPassword } = require("./admin_config");
const {
  sendProvisionWelcomeEmail,
  sendOrganizationInviteEmail,
  sendPlatformInviteEmail,
} = require("./institutional_emails");

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function stableInviteId(orgId, normalizedEmail) {
  const safeEmail = normalizedEmail
    .replace(/@/g, "_at_")
    .replace(/\./g, "_dot_")
    .replace(/\+/g, "_plus_");
  return `inv_${orgId}_${safeEmail}`;
}

function stablePlatformInviteId(normalizedEmail) {
  const safeEmail = normalizedEmail
    .replace(/@/g, "_at_")
    .replace(/\./g, "_dot_")
    .replace(/\+/g, "_plus_");
  return `inv_platform_${safeEmail}`;
}

function emptyRow(email) {
  return {
    email,
    displayName: null,
    created: false,
    invited: false,
    emailSent: false,
    emailFailed: false,
    emailError: null,
    skipped: false,
    skipReason: null,
    temporaryPassword: null,
  };
}

async function resolveGroupNames(db, orgId, groupIds) {
  if (!Array.isArray(groupIds) || groupIds.length === 0) return [];
  const names = [];
  for (const rawId of groupIds.slice(0, 20)) {
    const id = String(rawId || "").trim();
    if (!id) continue;
    const snap = await db
      .collection("organizations")
      .doc(orgId)
      .collection("groups")
      .doc(id)
      .get();
    const name = (snap.data()?.name || "").trim();
    if (name) names.push(name);
  }
  return names;
}

async function lookupAuth(auth, email) {
  try {
    return await auth.getUserByEmail(email);
  } catch (err) {
    if (err.code !== "auth/user-not-found") throw err;
    return null;
  }
}

function authHasLogin(record) {
  if (!record) return false;
  const providers = record.providerData || [];
  if (providers.length === 0) return false;
  const onlyAnonymous =
    providers.length === 1 && providers[0].providerId === "anonymous";
  return !onlyAnonymous;
}

async function lookupAuthAndMember(auth, db, orgId, email) {
  let uid = null;
  try {
    const record = await auth.getUserByEmail(email);
    uid = record.uid;
  } catch (err) {
    if (err.code !== "auth/user-not-found") throw err;
    return { uid: null, member: null };
  }
  const memberSnap = await db
    .collection("organizations")
    .doc(orgId)
    .collection("members")
    .doc(uid)
    .get();
  return {
    uid,
    member: memberSnap.exists ? memberSnap.data() : null,
  };
}

async function writePendingOrgInvite({
  db,
  orgId,
  email,
  organizationName,
  groupIds,
  invitedByUid,
  emailSubject,
  emailText,
}) {
  const inviteId = stableInviteId(orgId, email);
  const inviteRef = db
    .collection("organizations")
    .doc(orgId)
    .collection("invites")
    .doc(inviteId);
  const existing = await inviteRef.get();
  if (existing.exists && (existing.data()?.status || "pending") === "pending") {
    return { inviteId, alreadyPending: true };
  }

  const payload = {
    organizationId: orgId,
    email,
    role: "member",
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
    groupIds: Array.isArray(groupIds) ? groupIds : [],
    invitedByUid,
    organizationName: organizationName || null,
    emailHold: true,
  };
  if (emailSubject) payload.emailSubject = emailSubject;
  if (emailText) payload.emailText = emailText;

  const batch = db.batch();
  batch.set(inviteRef, payload, { merge: true });
  batch.set(
    db.collection("emailInvites").doc(email).collection("items").doc(inviteId),
    payload,
    { merge: true }
  );
  batch.set(
    db.collection("pendingOrgJoinsByEmail").doc(email).collection("orgs").doc(orgId),
    payload,
    { merge: true }
  );
  await batch.commit();
  return { inviteId, alreadyPending: false };
}

async function writePendingPlatformInvite({
  db,
  email,
  displayName,
  invitedByUid,
  emailSubject,
  emailText,
}) {
  const inviteId = stablePlatformInviteId(email);
  const inviteRef = db.collection("platformInvites").doc(inviteId);
  const existing = await inviteRef.get();
  if (existing.exists && (existing.data()?.status || "pending") === "pending") {
    return { inviteId, alreadyPending: true };
  }

  const payload = {
    email,
    displayName: displayName || null,
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
    invitedByUid,
    emailHold: true,
    kind: "platform",
  };
  if (emailSubject) payload.emailSubject = emailSubject;
  if (emailText) payload.emailText = emailText;
  await inviteRef.set(payload, { merge: true });
  return { inviteId, alreadyPending: false };
}

async function markPlatformInviteEmailResult(db, inviteId, sent) {
  const updates = sent
    ? {
        emailHold: false,
        inviteEmailSentAt: FieldValue.serverTimestamp(),
      }
    : { emailHold: true };
  await db.collection("platformInvites").doc(inviteId).set(updates, { merge: true });
}

async function markInviteEmailResult(db, orgId, email, inviteId, sent) {
  const updates = sent
    ? {
        emailHold: false,
        inviteEmailSentAt: FieldValue.serverTimestamp(),
      }
    : { emailHold: true };
  const refs = [
    db.collection("organizations").doc(orgId).collection("invites").doc(inviteId),
    db.collection("emailInvites").doc(email).collection("items").doc(inviteId),
  ];
  const batch = db.batch();
  for (const ref of refs) batch.set(ref, updates, { merge: true });
  await batch.commit();
}

async function sendInviteForRow({
  email,
  organizationName,
  groupNames,
  orgId,
  inviteId,
  emailSubject,
  emailText,
}) {
  return sendOrganizationInviteEmail({
    email,
    organizationName,
    role: "member",
    groupNames,
    orgId,
    inviteId,
    emailSubject,
    emailText,
  });
}

async function handleInviteMode({
  db,
  auth,
  orgId,
  organizationName,
  groupIds,
  groupNames,
  invitedByUid,
  users,
  emailSubject,
  emailText,
}) {
  const rows = [];
  for (const entry of users) {
    const email = normalizeEmail(entry?.email);
    const displayName = (entry?.displayName || "").trim() || null;
    const row = emptyRow(email);
    row.displayName = displayName;
    if (!email || !email.includes("@")) {
      row.skipped = true;
      row.skipReason = "invalid";
      rows.push(row);
      continue;
    }

    try {
      const { member } = await lookupAuthAndMember(auth, db, orgId, email);
      const existingGroups = Array.isArray(member?.groupIds) ? member.groupIds : [];
      const extraGroups = (groupIds || []).filter((id) => !existingGroups.includes(id));
      if (member && extraGroups.length === 0) {
        row.skipped = true;
        row.skipReason = "already_member";
        rows.push(row);
        continue;
      }

      const written = await writePendingOrgInvite({
        db,
        orgId,
        email,
        organizationName,
        groupIds: member ? extraGroups : groupIds,
        invitedByUid,
        emailSubject,
        emailText,
      });
      if (written.alreadyPending) {
        row.skipped = true;
        row.skipReason = "already_invited";
        rows.push(row);
        continue;
      }

      row.invited = true;
      const mail = await sendInviteForRow({
        email,
        organizationName,
        groupNames,
        orgId,
        inviteId: written.inviteId,
        emailSubject,
        emailText,
      });
      row.emailSent = mail.ok === true;
      row.emailFailed = mail.ok !== true;
      row.emailError = mail.error || null;
      await markInviteEmailResult(db, orgId, email, written.inviteId, mail.ok);
    } catch (err) {
      console.error("bulk invite error", email, err);
      row.skipped = true;
      row.skipReason = "error";
      row.emailError = err.message || "Invite failed";
    }
    rows.push(row);
  }
  return rows;
}

async function handleRegisterMode({
  db,
  auth,
  orgId,
  organizationName,
  groupIds,
  groupNames,
  invitedByUid,
  users,
  attachOrgInvite,
  emailSubject,
  emailText,
}) {
  const rows = [];
  for (const entry of users) {
    const email = normalizeEmail(entry?.email);
    const displayName = (entry?.displayName || "").trim() || null;
    const row = emptyRow(email);
    row.displayName = displayName;
    if (!email || !email.includes("@")) {
      row.skipped = true;
      row.skipReason = "invalid";
      rows.push(row);
      continue;
    }

    try {
      const existing = await lookupAuthAndMember(auth, db, orgId, email);
      if (existing.uid) {
        row.skipped = true;
        row.skipReason = "already_exists";
        if (attachOrgInvite && !existing.member) {
          const written = await writePendingOrgInvite({
            db,
            orgId,
            email,
            organizationName,
            groupIds,
            invitedByUid,
            emailSubject,
            emailText,
          });
          if (!written.alreadyPending) {
            row.invited = true;
            row.skipped = false;
            row.skipReason = null;
            const mail = await sendInviteForRow({
              email,
              organizationName,
              groupNames,
              orgId,
              inviteId: written.inviteId,
              emailSubject,
              emailText,
            });
            row.emailSent = mail.ok === true;
            row.emailFailed = mail.ok !== true;
            row.emailError = mail.error || null;
            await markInviteEmailResult(
              db,
              orgId,
              email,
              written.inviteId,
              mail.ok
            );
          }
        }
        rows.push(row);
        continue;
      }

      const tempPassword = generateTemporaryPassword();
      const userRecord = await auth.createUser({
        email,
        password: tempPassword,
        displayName: displayName || undefined,
        emailVerified: false,
      });

      await db.collection("users").doc(userRecord.uid).set(
        {
          email,
          displayName: displayName || null,
          mustChangePassword: true,
          accountStatus: "pending_password",
          hasSeenInstitutionalWelcome: false,
          provisionedByOrgId: orgId,
          shareAnonymouslyByDefault: true,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      row.created = true;
      row.temporaryPassword = tempPassword;

      if (attachOrgInvite) {
        const written = await writePendingOrgInvite({
          db,
          orgId,
          email,
          organizationName,
          groupIds,
          invitedByUid,
          emailSubject,
          emailText,
        });
        if (!written.alreadyPending) {
          row.invited = true;
          await markInviteEmailResult(db, orgId, email, written.inviteId, true);
        }
      }

      const welcomeEmail = await sendProvisionWelcomeEmail({
        email,
        displayName,
        temporaryPassword: tempPassword,
        organizationName,
        orgId,
        emailSubject,
        emailText,
      });
      row.emailSent = welcomeEmail.ok === true;
      row.emailFailed = welcomeEmail.ok !== true;
      row.emailError = welcomeEmail.error || null;
    } catch (err) {
      console.error("bulk register error", email, err);
      if (!row.created) {
        row.skipped = true;
        row.skipReason = "error";
      } else {
        row.emailFailed = true;
        row.emailError = err.message || "Email failed";
      }
    }
    rows.push(row);
  }
  return rows;
}

async function handlePlatformInviteMode({
  db,
  auth,
  invitedByUid,
  users,
  emailSubject,
  emailText,
}) {
  const rows = [];
  for (const entry of users) {
    const email = normalizeEmail(entry?.email);
    const displayName = (entry?.displayName || "").trim() || null;
    const row = emptyRow(email);
    row.displayName = displayName;
    if (!email || !email.includes("@")) {
      row.skipped = true;
      row.skipReason = "invalid";
      rows.push(row);
      continue;
    }

    try {
      const record = await lookupAuth(auth, email);
      if (authHasLogin(record)) {
        row.skipped = true;
        row.skipReason = "already_exists";
        rows.push(row);
        continue;
      }

      const written = await writePendingPlatformInvite({
        db,
        email,
        displayName,
        invitedByUid,
        emailSubject,
        emailText,
      });
      if (written.alreadyPending) {
        row.skipped = true;
        row.skipReason = "already_invited";
        rows.push(row);
        continue;
      }

      row.invited = true;
      const mail = await sendPlatformInviteEmail({
        email,
        inviteId: written.inviteId,
        emailSubject,
        emailText,
      });
      row.emailSent = mail.ok === true;
      row.emailFailed = mail.ok !== true;
      row.emailError = mail.error || null;
      await markPlatformInviteEmailResult(db, written.inviteId, mail.ok);
    } catch (err) {
      console.error("bulk platform invite error", email, err);
      row.skipped = true;
      row.skipReason = "error";
      row.emailError = err.message || "Invite failed";
    }
    rows.push(row);
  }
  return rows;
}

async function handlePlatformRegisterMode({
  db,
  auth,
  invitedByUid,
  users,
  emailSubject,
  emailText,
}) {
  const rows = [];
  for (const entry of users) {
    const email = normalizeEmail(entry?.email);
    const displayName = (entry?.displayName || "").trim() || null;
    const row = emptyRow(email);
    row.displayName = displayName;
    if (!email || !email.includes("@")) {
      row.skipped = true;
      row.skipReason = "invalid";
      rows.push(row);
      continue;
    }

    try {
      const record = await lookupAuth(auth, email);
      if (authHasLogin(record)) {
        row.skipped = true;
        row.skipReason = "already_exists";
        rows.push(row);
        continue;
      }

      const tempPassword = generateTemporaryPassword();
      const userRecord = await auth.createUser({
        email,
        password: tempPassword,
        displayName: displayName || undefined,
        emailVerified: false,
      });

      await db.collection("users").doc(userRecord.uid).set(
        {
          email,
          displayName: displayName || null,
          mustChangePassword: true,
          accountStatus: "pending_password",
          hasSeenInstitutionalWelcome: false,
          shareAnonymouslyByDefault: true,
          isAnonymous: false,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      row.created = true;
      row.temporaryPassword = tempPassword;

      const welcomeEmail = await sendProvisionWelcomeEmail({
        email,
        displayName,
        temporaryPassword: tempPassword,
        organizationName: null,
        orgId: null,
        emailSubject,
        emailText,
      });
      row.emailSent = welcomeEmail.ok === true;
      row.emailFailed = welcomeEmail.ok !== true;
      row.emailError = welcomeEmail.error || null;
    } catch (err) {
      console.error("bulk platform register error", email, err);
      if (!row.created) {
        row.skipped = true;
        row.skipReason = "error";
      } else {
        row.emailFailed = true;
        row.emailError = err.message || "Email failed";
      }
    }
    rows.push(row);
  }
  return rows;
}

async function handleBulkRoster({
  decoded,
  orgId,
  mode,
  users,
  groupIds,
  attachOrgInvite,
  emailSubject,
  emailText,
  canInvite,
  canRegister,
  isPlatform = false,
}) {
  if (mode !== "invite" && mode !== "register") {
    const err = new Error('mode must be "invite" or "register"');
    err.status = 400;
    throw err;
  }
  if (mode === "invite" && !canInvite) {
    const err = new Error("Missing sufficient permissions to send invitations");
    err.status = 403;
    throw err;
  }
  if (mode === "register" && !canRegister) {
    const err = new Error(
      "Only organization administrators can create accounts"
    );
    err.status = 403;
    throw err;
  }

  const db = getFirestore();
  const auth = getAuth();

  if (isPlatform) {
    const args = {
      db,
      auth,
      invitedByUid: decoded.uid,
      users,
      emailSubject,
      emailText,
    };
    const rows =
      mode === "invite"
        ? await handlePlatformInviteMode(args)
        : await handlePlatformRegisterMode(args);
    return { mode, target: "platform", rows };
  }

  const orgSnap = await db.collection("organizations").doc(orgId).get();
  if (!orgSnap.exists) {
    const err = new Error("Organization not found");
    err.status = 404;
    throw err;
  }
  const organizationName = (orgSnap.data()?.name || "").trim() || null;
  const names = await resolveGroupNames(db, orgId, groupIds);

  const args = {
    db,
    auth,
    orgId,
    organizationName,
    groupIds: Array.isArray(groupIds) ? groupIds.filter(Boolean) : [],
    groupNames: names,
    invitedByUid: decoded.uid,
    users,
    emailSubject,
    emailText,
  };

  const rows =
    mode === "invite"
      ? await handleInviteMode(args)
      : await handleRegisterMode({
          ...args,
          attachOrgInvite: attachOrgInvite !== false,
        });

  return { mode, target: "organization", rows };
}

module.exports = { handleBulkRoster };
