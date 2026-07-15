const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { BackupManager } = require('../lib/backup-manager');

function fixture(t) {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'haslim-backup-'));
    const dataDir = path.join(root, 'data');
    fs.mkdirSync(dataDir);
    const dbFiles = {
        users: path.join(dataDir, 'users.json'),
        activityLogs: path.join(dataDir, 'activity_logs.json')
    };
    fs.writeFileSync(dbFiles.users, JSON.stringify([{ id: 1 }]));
    fs.writeFileSync(dbFiles.activityLogs, JSON.stringify([]));
    const manager = new BackupManager({
        backupRoot: path.join(root, 'backups'),
        dbFiles,
        retention: 2
    });
    t.after(() => fs.rmSync(root, { recursive: true, force: true }));
    return { root, dbFiles, manager };
}

test('publishes complete backups and retains the newest two per type', t => {
    const { manager, dbFiles } = fixture(t);
    manager.createSnapshot('manual', { sequence: 1 });
    fs.writeFileSync(dbFiles.users, JSON.stringify([{ id: 2 }]));
    manager.createSnapshot('manual', { sequence: 2 });
    fs.writeFileSync(dbFiles.users, JSON.stringify([{ id: 3 }]));
    manager.createSnapshot('manual', { sequence: 3 });

    const manual = manager.listSnapshots('manual');
    assert.equal(manual.length, 2);
    assert.ok(manual.every(snapshot => snapshot.status === 'complete'));
    assert.equal(manager.listSnapshots('weekly').length, 0);
});

test('failed backup leaves existing completed backups untouched', t => {
    const { manager, dbFiles } = fixture(t);
    manager.createSnapshot('manual');
    manager.createSnapshot('manual');
    fs.rmSync(dbFiles.activityLogs);

    assert.throws(() => manager.createSnapshot('manual'), /Required data file is missing/);
    assert.equal(manager.listSnapshots('manual').length, 2);
    const entries = fs.readdirSync(path.join(manager.backupRoot, 'manual'));
    assert.equal(entries.some(name => name.endsWith('.incomplete')), false);
});

test('normalizes a complete legacy snapshot and rejects traversal', t => {
    const { manager } = fixture(t);
    const legacy = path.join(manager.backupRoot, '2026-07-01_10-00-00');
    fs.mkdirSync(legacy, { recursive: true });
    fs.writeFileSync(path.join(legacy, 'users.json'), JSON.stringify([{ id: 1 }]));
    fs.writeFileSync(path.join(legacy, 'activityLogs.json'), JSON.stringify([]));

    manager.normalizeLegacySnapshots();
    const snapshots = manager.listSnapshots('manual');
    assert.equal(snapshots.length, 1);
    assert.equal(snapshots[0].legacy, true);
    assert.ok(fs.existsSync(path.join(
        manager.backupRoot, 'manual', snapshots[0].name, 'activity_logs.json'
    )));
    assert.throws(() => manager.restoreSnapshot('manual', '../escape'), /Invalid backup name/);
});

test('validates and restores all files from a completed snapshot', t => {
    const { manager, dbFiles } = fixture(t);
    const snapshot = manager.createSnapshot('pre-reset');
    fs.writeFileSync(dbFiles.users, JSON.stringify([{ id: 99 }]));

    manager.restoreSnapshot('pre-reset', snapshot.name);
    assert.deepEqual(JSON.parse(fs.readFileSync(dbFiles.users, 'utf8')), [{ id: 1 }]);
});

test('pre-restore safety snapshot does not prune the requested backup early', t => {
    const { manager } = fixture(t);
    manager.createSnapshot('manual', { sequence: 1 });
    manager.createSnapshot('manual', { sequence: 2 });
    const requested = manager.listSnapshots('manual')[1];

    manager.createSnapshot('manual', { reason: 'pre-restore' }, { prune: false });
    assert.equal(manager.listSnapshots('manual').length, 3);
    assert.doesNotThrow(() => manager.restoreSnapshot('manual', requested.name));

    manager.pruneType('manual');
    assert.equal(manager.listSnapshots('manual').length, 2);
});
