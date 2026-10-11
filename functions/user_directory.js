const { onRequest } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { resendApiKey } = require("./email_config");
const { verifyIdToken, isSuperAdmin } = require("./usage_report_auth");
const {
  sendPlatformInviteEmail,
  sendOrganizationInviteEmail,
  sendGroupInviteEmail,
} = require("./institutional_emails");

function isRegisteredAuthUser(userRecord) {
  const providers = userRecord.providerData || [];
  if (providers.length === 0) return false;
  const onlyAnonymous =
    providers.length === 1 && providers[0].providerId === "anonymous";
  return !onlyAnonymous;
}

function toIso(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") {
    try {
      return value.toDate().toISOString();
    } catch (_) {
      return null;
    }
  }
  if (value instanceof Date) return value.toISOString();
  if (typeof value === "string" && value.trim()) {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? new Date(parsed).toISOString() : value;
  }
  return null;
}

function laterIso(a, b) {
  if (!a) return b || null;
  if (!b) return a;
  return Date.parse(a) >= Date.parse(b) ? a : b;
}

function namedLabel(value) {
  const text = String(value || "").trim();
  return text;
}

function pickProfileFields(data) {
  if (!data) return {};
  return {
    email: data.email || null,
    displayName: namedLabel(data.displayName) || null,
    lastActive: toIso(data.lastActive),
    createdAt: toIso(data.createdAt),
  };
}

async function listAuthUsers(auth) {
  const registered = [];
  let guestCount = 0;
  let nextPageToken;
  do {
    const page = await auth.listUsers(1000, nextPageToken);
    for (const user of page.users) {
      if (!isRegisteredAuthUser(user)) {
        guestCount += 1;
        continue;
      }
      registered.push(user);
    }
    nextPageToken = page.pageToken;
  } while (nextPageToken);
  return { registered, guestCount };
}

async function loadOrgAndGroupCatalog(db) {
  const orgSnap = await db.collection("organizations").get();
  const organizations = [];
  const orgNameById = {};
  const groups = [];
  const groupNameByKey = {};

  for (const orgDoc of orgSnap.docs) {
    const name = namedLabel(orgDoc.data()?.name);
    if (name) {
      organizations.push({ id: orgDoc.id, name });
      orgNameById[orgDoc.id] = name;
    } else {
      organizations.push({ id: orgDoc.id, name: "" });
    }
    const groupsSnap = await orgDoc.ref.collection("groups").get();
    for (const groupDoc of groupsSnap.docs) {
      const groupName = namedLabel(groupDoc.data()?.name);
      const orgName = orgNameById[orgDoc.id] || "";
      groups.push({
        id: groupDoc.id,
        name: groupName,
        organizationId: orgDoc.id,
        organizationName: orgName,
      });
      groupNameByKey[`${orgDoc.id}:${groupDoc.id}`] = groupName;
    }
  }

  organizations.sort((a, b) => a.name.localeCompare(b.name));
  groups.sort((a, b) => {
    const org = (a.organizationName || "").localeCompare(b.organizationName || "");
    if (org !== 0) return org;
    return (a.name || "").localeCompare(b.name || "");
  });

  return { organizations, groups, orgNameById, groupNameByKey };
}

async function loadMembershipsForUid(db, uid, catalog) {
  const [orgIndex, groupIndex] = await Promise.all([
    db.collection("users").doc(uid).collection("orgMemberships").get(),
    db.collection("users").doc(uid).collection("groupMemberships").get(),
  ]);

  const organizations = [];
  for (const doc of orgIndex.docs) {
    const orgId = doc.id || namedLabel(doc.data()?.organizationId);
    if (!orgId) continue;
    const name = catalog.orgNameById[orgId] || namedLabel(doc.data()?.organizationName);
    if (!name) continue;
    organizations.push({ id: orgId, name });
  }

  const groups = [];
  for (const doc of groupIndex.docs) {
    const data = doc.data() || {};
    const groupId = doc.id || namedLabel(data.groupId);
    const orgId = namedLabel(data.organizationId);
    if (!groupId) continue;
    const name =
      catalog.groupNameByKey[`${orgId}:${groupId}`] || namedLabel(data.groupName);
    if (!name) continue;
    groups.push({
      id: groupId,
      name,
      organizationId: orgId,
      organizationName: catalog.orgNameById[orgId] || namedLabel(data.organizationName),
    });
  }

  return { organizations, groups };
}

async function loadPendingInvites(db, catalog, registeredEmails) {
  const pending = [];

  const platformSnap = await db
    .collection("platformInvites")
    .where("status", "==", "pending")
    .get();
  for (const doc of platformSnap.docs) {
    const data = doc.data() || {};
    const email = String(data.email || "").trim().toLowerCase();
    if (!email) continue;
    if (registeredEmails.has(email)) {
      await doc.ref.set(
        {
          status: "accepted",
          acceptedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      continue;
    }
    pending.push({
      id: doc.id,
      kind: "platform",
      email,
      displayName: namedLabel(data.displayName) || null,
      createdAt: toIso(data.createdAt),
      organizationId: null,
      organizationName: "",
      groupId: null,
      groupName: "",
      hasAccount: false,
    });
  }

  for (const org of catalog.organizations) {
    const [orgInvites, groupInvites] = await Promise.all([
      db
        .collection("organizations")
        .doc(org.id)
        .collection("invites")
        .where("status", "==", "pending")
        .get(),
      db
        .collection("organizations")
        .doc(org.id)
        .collection("groupInvites")
        .where("status", "==", "pending")
        .get(),
    ]);

    for (const doc of orgInvites.docs) {
      const data = doc.data() || {};
      const email = String(data.email || data.inviteeEmail || "")
        .trim()
        .toLowerCase();
      if (!email) continue;
      pending.push({
        id: doc.id,
        kind: "org",
        email,
        displayName: namedLabel(data.displayName) || null,
        createdAt: toIso(data.createdAt),
        organizationId: org.id,
        organizationName: org.name,
        groupId: null,
        groupName: "",
        hasAccount: registeredEmails.has(email),
      });
    }

    for (const doc of groupInvites.docs) {
      const data = doc.data() || {};
      const email = String(data.inviteeEmail || data.email || "")
        .trim()
        .toLowerCase();
      if (!email) continue;
      const groupName =
        namedLabel(data.groupName) ||
        catalog.groupNameByKey[`${org.id}:${data.groupId}`] ||
        "";
      pending.push({
        id: doc.id,
        kind: "group",
        email,
        displayName: namedLabel(data.displayName) || null,
        createdAt: toIso(data.createdAt),
        organizationId: org.id,
        organizationName: org.name || namedLabel(data.organizationName),
        groupId: namedLabel(data.groupId) || null,
        groupName,
        hasAccount: registeredEmails.has(email),
      });
    }
  }

  pending.sort((a, b) => String(b.createdAt || "").localeCompare(String(a.createdAt || "")));
  return pending;
}

async function buildDirectory() {
  const db = getFirestore();
  const auth = getAuth();
  const [{ registered, guestCount }, catalog] = await Promise.all([
    listAuthUsers(auth),
    loadOrgAndGroupCatalog(db),
  ]);

  const registeredEmails = new Set(
    registered
      .map((user) => String(user.email || "").trim().toLowerCase())
      .filter(Boolean)
  );

  const userRefs = registered.map((user) => db.collection("users").doc(user.uid));
  const profileSnaps = [];
  for (let i = 0; i < userRefs.length; i += 100) {
    const chunk = userRefs.slice(i, i + 100);
    if (chunk.length === 0) continue;
    const snaps = await db.getAll(...chunk);
    profileSnaps.push(...snaps);
  }

  const users = [];
  for (let i = 0; i < registered.length; i += 1) {
    const record = registered[i];
    const profile = pickProfileFields(
      profileSnaps[i] && profileSnaps[i].exists ? profileSnaps[i].data() : null
    );
    const memberships = await loadMembershipsForUid(db, record.uid, catalog);
    const email = String(record.email || profile.email || "").trim().toLowerCase();
    const displayName =
      namedLabel(profile.displayName) || namedLabel(record.displayName) || "";
    const lastActive = laterIso(
      profile.lastActive,
      toIso(record.metadata?.lastSignInTime)
    );

    users.push({
      uid: record.uid,
      email,
      displayName,
      status: "registered",
      lastActive,
      createdAt: profile.createdAt || toIso(record.metadata?.creationTime),
      organizations: memberships.organizations,
      groups: memberships.groups,
    });
  }

  users.sort((a, b) => {
    const name = (a.displayName || a.email).localeCompare(b.displayName || b.email);
    if (name !== 0) return name;
    return a.email.localeCompare(b.email);
  });

  const pendingInvites = await loadPendingInvites(db, catalog, registeredEmails);

  return {
    generatedAt: new Date().toISOString(),
    guestCount,
    users,
    pendingInvites,
    organizations: catalog.organizations.filter((org) => org.name),
    groups: catalog.groups.filter((group) => group.name),
    note:
      "Directory fields only. Seeking God's Wisdom, Reflections, and personal Gifts are never included.",
  };
}

async function resendInvite({ kind, inviteId, orgId }) {
  const db = getFirestore();
  const type = String(kind || "").trim();
  const id = String(inviteId || "").trim();
  if (!id) {
    const err = new Error("inviteId required");
    err.status = 400;
    throw err;
  }

  if (type === "platform") {
    const ref = db.collection("platformInvites").doc(id);
    const snap = await ref.get();
    if (!snap.exists) {
      const err = new Error("Invitation not found");
      err.status = 404;
      throw err;
    }
    const data = snap.data() || {};
    if ((data.status || "pending") !== "pending") {
      const err = new Error("Invitation is no longer pending");
      err.status = 400;
      throw err;
    }
    const email = String(data.email || "").trim().toLowerCase();
    const mail = await sendPlatformInviteEmail({
      email,
      inviteId: id,
      emailSubject: data.emailSubject,
      emailText: data.emailText,
    });
    if (mail.ok) {
      await ref.set(
        {
          emailHold: false,
          inviteEmailSentAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
    return { ok: mail.ok === true, error: mail.error || null };
  }

  if (type === "org") {
    const organizationId = String(orgId || "").trim();
    if (!organizationId) {
      const err = new Error("orgId required");
      err.status = 400;
      throw err;
    }
    const ref = db
      .collection("organizations")
      .doc(organizationId)
      .collection("invites")
      .doc(id);
    const snap = await ref.get();
    if (!snap.exists) {
      const err = new Error("Invitation not found");
      err.status = 404;
      throw err;
    }
    const data = snap.data() || {};
    const email = String(data.email || "").trim().toLowerCase();
    const orgSnap = await db.collection("organizations").doc(organizationId).get();
    const organizationName =
      namedLabel(data.organizationName) || namedLabel(orgSnap.data()?.name);
    const groupNames = [];
    for (const rawId of Array.isArray(data.groupIds) ? data.groupIds : []) {
      const groupId = String(rawId || "").trim();
      if (!groupId) continue;
      const groupSnap = await db
        .collection("organizations")
        .doc(organizationId)
        .collection("groups")
        .doc(groupId)
        .get();
      const groupName = namedLabel(groupSnap.data()?.name);
      if (groupName) groupNames.push(groupName);
    }
    const mail = await sendOrganizationInviteEmail({
      email,
      organizationName,
      role: data.role || "member",
      groupNames,
      orgId: organizationId,
      inviteId: id,
      emailSubject: data.emailSubject,
      emailText: data.emailText,
    });
    if (mail.ok) {
      await ref.set(
        {
          emailHold: false,
          inviteEmailSentAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
    return { ok: mail.ok === true, error: mail.error || null };
  }

  if (type === "group") {
    const organizationId = String(orgId || "").trim();
    if (!organizationId) {
      const err = new Error("orgId required");
      err.status = 400;
      throw err;
    }
    const ref = db
      .collection("organizations")
      .doc(organizationId)
      .collection("groupInvites")
      .doc(id);
    const snap = await ref.get();
    if (!snap.exists) {
      const err = new Error("Invitation not found");
      err.status = 404;
      throw err;
    }
    const data = snap.data() || {};
    const email = String(data.inviteeEmail || data.email || "")
      .trim()
      .toLowerCase();
    const orgSnap = await db.collection("organizations").doc(organizationId).get();
    const mail = await sendGroupInviteEmail({
      email,
      groupName: namedLabel(data.groupName),
      organizationName:
        namedLabel(data.organizationName) || namedLabel(orgSnap.data()?.name),
      orgId: organizationId,
      inviteId: id,
      emailSubject: data.emailSubject,
      emailText: data.emailText,
    });
    if (mail.ok) {
      await ref.set(
        {
          emailHold: false,
          inviteEmailSentAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
    return { ok: mail.ok === true, error: mail.error || null };
  }

  const err = new Error('kind must be "platform", "org", or "group"');
  err.status = 400;
  throw err;
}

function registerUserDirectoryFunctions(exports) {
  exports.getUserDirectory = onRequest(
    {
      cors: true,
      invoker: "public",
      timeoutSeconds: 120,
      memory: "512MiB",
    },
    async (req, res) => {
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      try {
        const decoded = await verifyIdToken(req);
        const db = getFirestore();
        if (!(await isSuperAdmin(db, decoded))) {
          res.status(403).json({ error: "Overall Admin access required" });
          return;
        }
        const directory = await buildDirectory();
        res.status(200).json(directory);
      } catch (err) {
        res
          .status(err.status || 500)
          .json({ error: err.message || "Failed to load users" });
      }
    }
  );

  exports.resendDirectoryInvite = onRequest(
    {
      cors: true,
      invoker: "public",
      secrets: [resendApiKey],
    },
    async (req, res) => {
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      try {
        const decoded = await verifyIdToken(req);
        const db = getFirestore();
        if (!(await isSuperAdmin(db, decoded))) {
          res.status(403).json({ error: "Overall Admin access required" });
          return;
        }
        const result = await resendInvite({
          kind: req.body?.kind,
          inviteId: req.body?.inviteId,
          orgId: req.body?.orgId,
        });
        res.status(200).json(result);
      } catch (err) {
        res
          .status(err.status || 500)
          .json({ error: err.message || "Failed to resend invitation" });
      }
    }
  );
}

module.exports = { registerUserDirectoryFunctions };
