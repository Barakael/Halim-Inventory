const test = require('node:test');
const assert = require('node:assert/strict');
const {
    ABSOLUTE_TIMEOUT_MS,
    destroySession,
    FixedWindowRateLimiter,
    IDLE_TIMEOUT_MS,
    removeExpiredLowStockNotifications,
    sessionExpiryReason
} = require('../lib/security');

test('session policy uses 15-minute idle and two-hour absolute limits', () => {
    assert.equal(IDLE_TIMEOUT_MS, 15 * 60 * 1000);
    assert.equal(ABSOLUTE_TIMEOUT_MS, 2 * 60 * 60 * 1000);

    const now = Date.now();
    const active = { user: { id: '1' }, startedAt: new Date(now - ABSOLUTE_TIMEOUT_MS + 1).toISOString() };
    const expired = { user: { id: '1' }, startedAt: new Date(now - ABSOLUTE_TIMEOUT_MS).toISOString() };
    assert.equal(sessionExpiryReason(active, now), null);
    assert.equal(sessionExpiryReason(expired, now), 'absolute');
    assert.equal(sessionExpiryReason({ user: { id: '1' } }, now), 'invalid');
});

test('rate limiter blocks only within its window and can be reset', () => {
    const limiter = new FixedWindowRateLimiter({ limit: 2, windowMs: 1000 });
    assert.equal(limiter.consume('client', 100).allowed, true);
    assert.equal(limiter.consume('client', 200).allowed, true);
    assert.equal(limiter.consume('client', 300).allowed, false);

    limiter.reset('client');
    assert.equal(limiter.consume('client', 400).allowed, true);
    assert.equal(limiter.consume('other', 2000).allowed, true);
    assert.equal(limiter.consume('client', 2000).allowed, true);
});

test('successful logout waits for session destruction', async () => {
    let destroyed = false;
    const session = {
        destroy(callback) {
            destroyed = true;
            callback(null);
        }
    };

    await destroySession(session);
    assert.equal(destroyed, true);
});

test('low-stock cleanup removes only valid timestamps older than seven days', () => {
    const now = Date.parse('2026-07-15T12:00:00.000Z');
    const notifications = [
        { id: 'old', type: 'low_stock', createdAt: '2026-07-08T11:59:59.999Z' },
        { id: 'boundary', type: 'low_stock', createdAt: '2026-07-08T12:00:00.000Z' },
        { id: 'new', type: 'low_stock', createdAt: '2026-07-14T12:00:00.000Z' },
        { id: 'expiry', type: 'expiry', createdAt: '2026-01-01T00:00:00.000Z' },
        { id: 'invalid', type: 'low_stock', createdAt: 'not-a-date' }
    ];

    const result = removeExpiredLowStockNotifications(notifications, now);
    assert.equal(result.removed, 1);
    assert.equal(result.malformed, 1);
    assert.deepEqual(result.notifications.map(item => item.id), [
        'boundary', 'new', 'expiry', 'invalid'
    ]);
    assert.deepEqual(
        removeExpiredLowStockNotifications(result.notifications, now).notifications,
        result.notifications
    );
});
