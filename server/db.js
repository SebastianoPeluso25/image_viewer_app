const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs-extra');

const dbPath = path.join(__dirname, 'photos.db');
const db = new Database(dbPath);

// Initialize database
db.exec(`
  CREATE TABLE IF NOT EXISTS photos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    path TEXT NOT NULL UNIQUE,
    size INTEGER,
    mime_type TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
  )
`);

// Cartelle rimosse dall'app: le loro foto non vengono mostrate né riscansionate.
// NB: i file sul disco NON vengono mai toccati, si agisce solo sul database.
db.exec(`
  CREATE TABLE IF NOT EXISTS excluded_folders (
    path TEXT PRIMARY KEY,
    removed_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
`);

// Inizializza il tema se non esiste
db.prepare("INSERT OR IGNORE INTO settings (key, value) VALUES ('theme', 'light')").run();

const insertPhoto = db.prepare('INSERT OR IGNORE INTO photos (name, path, size, mime_type) VALUES (?, ?, ?, ?)');
const getAllPhotos = db.prepare('SELECT * FROM photos ORDER BY created_at DESC');

const SORT_FIELDS = ['created_at', 'name', 'size'];

const getPhotosFiltered = (filter) => {
    let query = 'SELECT * FROM photos';
    const conditions = [];
    const params = [];

    if (filter && filter.name) {
        conditions.push('name LIKE ?');
        params.push(`%${filter.name}%`);
    }

    // Prefiltro per cartella (il filtro esatto sulla cartella padre avviene in server.js)
    if (filter && filter.folder) {
        conditions.push('lower(substr(path, 1, ?)) = lower(?)');
        params.push(filter.folder.length, filter.folder);
    }

    if (conditions.length > 0) {
        query += ' WHERE ' + conditions.join(' AND ');
    }

    // Whitelist per evitare SQL injection nell'ORDER BY
    const sortField = SORT_FIELDS.includes(filter?.sortBy) ? filter.sortBy : 'created_at';
    const sortOrder = filter?.order === 'ASC' ? 'ASC' : 'DESC';
    query += ` ORDER BY ${sortField} ${sortOrder}`;

    return db.prepare(query).all(params);
};

const getSetting = (key) => {
    return db.prepare('SELECT value FROM settings WHERE key = ?').get(key);
};

const getExcludedFolders = () =>
    db.prepare('SELECT path FROM excluded_folders ORDER BY path').all().map((r) => r.path);

/**
 * Rimuove una cartella SOLO dall'app: la aggiunge alle escluse e cancella dal database
 * le righe delle foto contenute (anche nelle sottocartelle). Nessun file viene eliminato.
 * Restituisce il numero di foto rimosse dal database.
 */
const excludeFolder = db.transaction((folder) => {
    db.prepare('INSERT OR IGNORE INTO excluded_folders (path) VALUES (?)').run(folder);
    const prefix = folder.endsWith(path.sep) ? folder : folder + path.sep;
    return db
        .prepare('DELETE FROM photos WHERE lower(substr(path, 1, ?)) = lower(?)')
        .run(prefix.length, prefix).changes;
});

const restoreFolder = (folder) =>
    db.prepare('DELETE FROM excluded_folders WHERE lower(path) = lower(?)').run(folder).changes;

const getAllSettings = () => {
    const rows = db.prepare('SELECT key, value FROM settings').all();
    return Object.fromEntries(rows.map((r) => [r.key, r.value]));
};

const updateSetting = (key, value) => {
    return db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)').run(key, value);
};

module.exports = {
    db,
    insertPhoto,
    getAllPhotos,
    getPhotosFiltered,
    getSetting,
    getAllSettings,
    getExcludedFolders,
    excludeFolder,
    restoreFolder,
    updateSetting
};
