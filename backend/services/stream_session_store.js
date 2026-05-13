const crypto = require('crypto');

const SESSION_TTL_MS = 20 * 60 * 1000;
const sessions = new Map();

function cleanupExpiredSessions() {
  const now = Date.now();
  for (const [id, session] of sessions.entries()) {
    if (session.expiresAt <= now) {
      sessions.delete(id);
    }
  }
}

function createStreamSession({ targetUrl, headers = {}, sourceUrl = null }) {
  cleanupExpiredSessions();

  const id = crypto.randomBytes(16).toString('hex');
  const expiresAt = Date.now() + SESSION_TTL_MS;

  sessions.set(id, {
    id,
    targetUrl,
    sourceUrl,
    headers,
    expiresAt,
    createdAt: Date.now()
  });

  return sessions.get(id);
}

function getStreamSession(id) {
  cleanupExpiredSessions();

  const session = sessions.get(id);
  if (!session || session.expiresAt <= Date.now()) {
    sessions.delete(id);
    return null;
  }

  session.expiresAt = Date.now() + SESSION_TTL_MS;
  return session;
}

module.exports = {
  createStreamSession,
  getStreamSession
};
