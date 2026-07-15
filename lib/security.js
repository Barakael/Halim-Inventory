const IDLE_TIMEOUT_MS = 15 * 60 * 1000;
const ABSOLUTE_TIMEOUT_MS = 2 * 60 * 60 * 1000;
const LOW_STOCK_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;

class FixedWindowRateLimiter {
    constructor({ limit, windowMs }) {
        this.limit = limit;
        this.windowMs = windowMs;
        this.entries = new Map();
    }

    consume(key, now = Date.now()) {
        const existing = this.entries.get(key);
        const entry = !existing || existing.resetAt <= now
            ? { count: 0, resetAt: now + this.windowMs }
            : existing;

        entry.count += 1;
        this.entries.set(key, entry);

        return {
            allowed: entry.count <= this.limit,
            remaining: Math.max(0, this.limit - entry.count),
            retryAfterSeconds: Math.max(1, Math.ceil((entry.resetAt - now) / 1000))
        };
    }

    reset(key) {
        this.entries.delete(key);
    }

    prune(now = Date.now()) {
        for (const [key, entry] of this.entries) {
            if (entry.resetAt <= now) this.entries.delete(key);
        }
    }
}

function sessionExpiryReason(sessionData, now = Date.now()) {
    if (!sessionData?.user) return 'unauthenticated';

    const startedAt = Date.parse(sessionData.startedAt);
    if (!Number.isFinite(startedAt)) return 'invalid';
    if (now - startedAt >= ABSOLUTE_TIMEOUT_MS) return 'absolute';

    return null;
}

function destroySession(session) {
    return new Promise((resolve, reject) => {
        session.destroy(error => error ? reject(error) : resolve());
    });
}

function removeExpiredLowStockNotifications(notifications, now = Date.now()) {
    const cutoff = now - LOW_STOCK_RETENTION_MS;
    let removed = 0;
    let malformed = 0;

    const retained = notifications.filter(notification => {
        if (notification.type !== 'low_stock') return true;

        const createdAt = Date.parse(notification.createdAt);
        if (!Number.isFinite(createdAt)) {
            malformed += 1;
            return true;
        }

        if (createdAt < cutoff) {
            removed += 1;
            return false;
        }
        return true;
    });

    return { notifications: retained, removed, malformed };
}

module.exports = {
    ABSOLUTE_TIMEOUT_MS,
    destroySession,
    FixedWindowRateLimiter,
    IDLE_TIMEOUT_MS,
    LOW_STOCK_RETENTION_MS,
    removeExpiredLowStockNotifications,
    sessionExpiryReason
};
