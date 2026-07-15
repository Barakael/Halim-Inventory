const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const BACKUP_TYPES = ['manual', 'weekly', 'pre-reset'];

function hashFile(filePath) {
    return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

function safeTimestamp(date = new Date()) {
    return date.toISOString().replace(/[:.]/g, '-');
}

class BackupManager {
    constructor({ backupRoot, dbFiles, retention = 2 }) {
        this.backupRoot = backupRoot;
        this.dbFiles = dbFiles;
        this.retention = retention;
    }

    ensureLayout() {
        fs.mkdirSync(this.backupRoot, { recursive: true });
        BACKUP_TYPES.forEach(type => {
            fs.mkdirSync(path.join(this.backupRoot, type), { recursive: true });
        });
    }

    normalizeLegacySnapshots() {
        this.ensureLayout();

        for (const entry of fs.readdirSync(this.backupRoot, { withFileTypes: true })) {
            if (!entry.isDirectory() || BACKUP_TYPES.includes(entry.name) || entry.name.startsWith('.')) continue;

            const type = entry.name.startsWith('backup-') ? 'pre-reset' : 'manual';
            const source = path.join(this.backupRoot, entry.name);
            const destination = path.join(this.backupRoot, type, entry.name);
            if (!fs.existsSync(destination)) fs.renameSync(source, destination);
        }

        for (const type of BACKUP_TYPES) {
            const typeDir = path.join(this.backupRoot, type);
            for (const entry of fs.readdirSync(typeDir, { withFileTypes: true })) {
                if (!entry.isDirectory() || entry.name.startsWith('.')) continue;
                this.normalizeSnapshot(type, entry.name);
            }
        }
    }

    normalizeSnapshot(type, name) {
        const snapshotDir = this.snapshotPath(type, name);
        const manifestPath = path.join(snapshotDir, 'manifest.json');

        try {
            const existingManifest = fs.existsSync(manifestPath)
                ? JSON.parse(fs.readFileSync(manifestPath, 'utf8'))
                : {};
            if (existingManifest.status === 'complete' && existingManifest.files) return existingManifest;

            const files = {};
            for (const [key, sourcePath] of Object.entries(this.dbFiles)) {
                const canonicalName = path.basename(sourcePath);
                const canonicalPath = path.join(snapshotDir, canonicalName);
                const legacyPath = path.join(snapshotDir, `${key}.json`);

                if (!fs.existsSync(canonicalPath) && fs.existsSync(legacyPath)) {
                    fs.copyFileSync(legacyPath, canonicalPath);
                }
                if (!fs.existsSync(canonicalPath)) return null;

                JSON.parse(fs.readFileSync(canonicalPath, 'utf8'));
                files[key] = {
                    name: canonicalName,
                    bytes: fs.statSync(canonicalPath).size,
                    sha256: hashFile(canonicalPath)
                };
            }

            const completedAt = existingManifest.completedAt || existingManifest.createdAt ||
                fs.statSync(snapshotDir).mtime.toISOString();
            const manifest = {
                ...existingManifest,
                version: 1,
                status: 'complete',
                type,
                name,
                completedAt,
                legacy: true,
                files
            };
            fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
            return manifest;
        } catch (error) {
            console.warn(`Backup ${type}/${name} was not normalized: ${error.message}`);
            return null;
        }
    }

    createSnapshot(type, metadata = {}, options = {}) {
        this.assertType(type);
        this.ensureLayout();

        const name = `${safeTimestamp()}-${crypto.randomBytes(3).toString('hex')}`;
        const typeDir = path.join(this.backupRoot, type);
        const stagingDir = path.join(typeDir, `.${name}.incomplete`);
        const finalDir = path.join(typeDir, name);

        fs.mkdirSync(stagingDir);
        try {
            const files = {};
            for (const [key, sourcePath] of Object.entries(this.dbFiles)) {
                if (!fs.existsSync(sourcePath)) {
                    throw new Error(`Required data file is missing: ${path.basename(sourcePath)}`);
                }

                const fileName = path.basename(sourcePath);
                const destination = path.join(stagingDir, fileName);
                fs.copyFileSync(sourcePath, destination);
                JSON.parse(fs.readFileSync(destination, 'utf8'));
                files[key] = {
                    name: fileName,
                    bytes: fs.statSync(destination).size,
                    sha256: hashFile(destination)
                };
            }

            const latestCompletedAt = this.listSnapshots(type)
                .reduce((latest, snapshot) => Math.max(latest, Date.parse(snapshot.completedAt) || 0), 0);
            const completedAt = new Date(Math.max(Date.now(), latestCompletedAt + 1)).toISOString();
            const manifest = {
                version: 1,
                status: 'complete',
                type,
                name,
                completedAt,
                metadata,
                files
            };
            fs.writeFileSync(path.join(stagingDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
            fs.renameSync(stagingDir, finalDir);

            const pruneResult = options.prune === false
                ? { removed: [], errors: [] }
                : this.pruneType(type);
            return { ...manifest, path: finalDir, pruneResult };
        } catch (error) {
            fs.rmSync(stagingDir, { recursive: true, force: true });
            throw error;
        }
    }

    listSnapshots(type) {
        this.assertType(type);
        const typeDir = path.join(this.backupRoot, type);
        if (!fs.existsSync(typeDir)) return [];

        return fs.readdirSync(typeDir, { withFileTypes: true })
            .filter(entry => entry.isDirectory() && !entry.name.startsWith('.'))
            .map(entry => {
                try {
                    const manifest = this.readAndValidateSnapshot(type, entry.name);
                    if (!Number.isFinite(Date.parse(manifest.completedAt))) return null;
                    return { ...manifest, name: entry.name };
                } catch {
                    return null;
                }
            })
            .filter(Boolean)
            .sort((a, b) => Date.parse(b.completedAt) - Date.parse(a.completedAt));
    }

    listAllSnapshots() {
        return BACKUP_TYPES.flatMap(type => this.listSnapshots(type));
    }

    pruneType(type) {
        const snapshots = this.listSnapshots(type);
        const removed = [];
        const errors = [];

        for (const snapshot of snapshots.slice(this.retention)) {
            try {
                fs.rmSync(this.snapshotPath(type, snapshot.name), { recursive: true });
                removed.push(snapshot.name);
            } catch (error) {
                errors.push({ name: snapshot.name, message: error.message });
            }
        }
        return { removed, errors };
    }

    restoreSnapshot(type, name) {
        const manifest = this.readAndValidateSnapshot(type, name);
        const stagedFiles = [];

        try {
            for (const [key, source] of Object.entries(this.dbFiles)) {
                const backupFile = path.join(this.snapshotPath(type, name), manifest.files[key].name);
                const tempFile = `${source}.restore.tmp`;
                fs.copyFileSync(backupFile, tempFile);
                JSON.parse(fs.readFileSync(tempFile, 'utf8'));
                stagedFiles.push({ source, tempFile });
            }
            stagedFiles.forEach(({ source, tempFile }) => fs.renameSync(tempFile, source));
            return manifest;
        } catch (error) {
            stagedFiles.forEach(({ tempFile }) => fs.rmSync(tempFile, { force: true }));
            throw error;
        }
    }

    readAndValidateSnapshot(type, name) {
        const snapshotDir = this.snapshotPath(type, name);
        const manifest = JSON.parse(fs.readFileSync(path.join(snapshotDir, 'manifest.json'), 'utf8'));
        if (manifest.status !== 'complete' || manifest.type !== type) {
            throw new Error('Backup is not complete');
        }

        for (const [key, details] of Object.entries(manifest.files || {})) {
            if (!this.dbFiles[key]) continue;
            if (!details.name || path.basename(details.name) !== details.name) {
                throw new Error(`Invalid backup filename: ${details.name}`);
            }
            const filePath = path.join(snapshotDir, details.name);
            JSON.parse(fs.readFileSync(filePath, 'utf8'));
            if (hashFile(filePath) !== details.sha256) {
                throw new Error(`Backup integrity check failed: ${details.name}`);
            }
        }
        for (const key of Object.keys(this.dbFiles)) {
            if (!manifest.files?.[key]) throw new Error(`Backup file missing from manifest: ${key}`);
        }
        return manifest;
    }

    snapshotPath(type, name) {
        this.assertType(type);
        if (!name || path.basename(name) !== name || name === '.' || name === '..') {
            throw new Error('Invalid backup name');
        }
        return path.join(this.backupRoot, type, name);
    }

    assertType(type) {
        if (!BACKUP_TYPES.includes(type)) throw new Error('Invalid backup type');
    }
}

module.exports = { BACKUP_TYPES, BackupManager };
