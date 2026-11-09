const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs-extra');
const { db, insertPhoto, getPhotosFiltered, getSetting, getAllSettings, updateSetting,
    getExcludedFolders, excludeFolder, restoreFolder } = require('./db');

const app = express();
const PORT = 3000;

const IMAGE_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
const MAX_DEPTH = 10;

app.use(cors());
app.use(express.json());

const isImage = (fileName) => IMAGE_EXTENSIONS.includes(path.extname(fileName).toLowerCase());

// Legge una cartella ignorando quelle non accessibili (permessi, link rotti, ecc.)
async function safeReadDir(dir) {
    try {
        return await fs.readdir(dir, { withFileTypes: true });
    } catch (_) {
        return [];
    }
}

// true se la cartella (o una cartella che la contiene) è stata rimossa dall'app
function isExcluded(dir, excluded) {
    const d = path.resolve(dir).toLowerCase();
    return excluded.some((e) => {
        const ex = e.toLowerCase();
        return d === ex || d.startsWith(ex.endsWith(path.sep) ? ex : ex + path.sep);
    });
}

// Scansiona ricorsivamente una cartella e inserisce nel DB tutte le immagini trovate
async function scanRecursive(dir, depth = 0, excluded = getExcludedFolders()) {
    let count = 0;
    if (isExcluded(dir, excluded)) return 0;
    for (const entry of await safeReadDir(dir)) {
        if (entry.name.startsWith('.')) continue;
        const fullPath = path.join(dir, entry.name);

        if (entry.isDirectory()) {
            if (depth < MAX_DEPTH) count += await scanRecursive(fullPath, depth + 1, excluded);
        } else if (entry.isFile() && isImage(entry.name)) {
            const stats = await fs.stat(fullPath);
            const ext = path.extname(entry.name).toLowerCase().replace('.', '');
            insertPhoto.run(entry.name, fullPath, stats.size, `image/${ext}`);
            count++;
        }
    }
    return count;
}

// Costruisce l'albero delle cartelle che contengono (direttamente o nelle sottocartelle) almeno una foto
async function buildFolderTree(dir, depth = 0, excluded = getExcludedFolders()) {
    let photoCount = 0;
    const children = [];

    for (const entry of await safeReadDir(dir)) {
        if (entry.name.startsWith('.')) continue;

        if (entry.isDirectory()) {
            const childPath = path.join(dir, entry.name);
            if (depth < MAX_DEPTH && !isExcluded(childPath, excluded)) {
                const child = await buildFolderTree(childPath, depth + 1, excluded);
                if (child.totalCount > 0) children.push(child);
            }
        } else if (entry.isFile() && isImage(entry.name)) {
            photoCount++;
        }
    }

    children.sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true }));
    const totalCount = children.reduce((sum, c) => sum + c.totalCount, photoCount);

    return {
        name: path.basename(dir) || dir,
        path: dir,
        photoCount,
        totalCount,
        children,
    };
}

// Endpoint to scan a directory (recursively)
app.post('/api/scan', async (req, res) => {
    const { folderPath } = req.body;

    if (!folderPath || !fs.existsSync(folderPath)) {
        return res.status(400).json({ error: 'Invalid folder path' });
    }

    try {
        const count = await scanRecursive(path.resolve(folderPath));
        res.json({ message: `Scanned ${count} photos`, count });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to scan directory' });
    }
});

// Endpoint to get the folder tree of a root directory
app.get('/api/folders', async (req, res) => {
    const { root } = req.query;

    if (!root || !fs.existsSync(root)) {
        return res.status(400).json({ error: 'Invalid root folder' });
    }

    try {
        res.json(await buildFolderTree(path.resolve(root)));
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to read folders' });
    }
});

// Valida una lista di percorsi ricevuta dal client
function parsePaths(body) {
    const paths = Array.isArray(body?.paths) ? body.paths : [];
    return paths.filter((p) => typeof p === 'string' && p.trim()).map((p) => path.resolve(p));
}

// Elenco delle cartelle rimosse dall'app
app.get('/api/folders/excluded', (req, res) => {
    res.json(getExcludedFolders());
});

// Rimuove una o più cartelle SOLO dall'app e dal database.
// IMPORTANTE: nessun file o cartella viene eliminato dal computer.
app.post('/api/folders/remove', (req, res) => {
    const paths = parsePaths(req.body);
    if (paths.length === 0) return res.status(400).json({ error: 'No folders given' });

    let removedPhotos = 0;
    for (const folder of paths) removedPhotos += excludeFolder(folder);
    res.json({ removedFolders: paths.length, removedPhotos });
});

// Ripristina cartelle rimosse: tornano visibili e vengono riscansionate
app.post('/api/folders/restore', async (req, res) => {
    const paths = parsePaths(req.body);
    if (paths.length === 0) return res.status(400).json({ error: 'No folders given' });

    try {
        let restoredPhotos = 0;
        for (const folder of paths) {
            restoreFolder(folder);
            if (fs.existsSync(folder)) restoredPhotos += await scanRecursive(folder);
        }
        res.json({ restoredFolders: paths.length, restoredPhotos });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to restore folders' });
    }
});

// Endpoint to get photos with filtering/sorting
app.get('/api/photos', (req, res) => {
    const { name, sortBy, order, folder } = req.query;
    let photos = getPhotosFiltered({ name, sortBy, order, folder: folder ? path.resolve(folder) : undefined });

    // Solo le foto direttamente dentro la cartella selezionata (non quelle delle sottocartelle)
    if (folder) {
        const target = path.resolve(folder).toLowerCase();
        photos = photos.filter((p) => path.dirname(p.path).toLowerCase() === target);
    }

    res.json(photos);
});

// Endpoint to serve the image file
app.get('/api/photo/:id', (req, res) => {
    const { id } = req.params;
    const photo = db.prepare('SELECT path FROM photos WHERE id = ?').get(id);

    if (photo && fs.existsSync(photo.path)) {
        res.sendFile(photo.path);
    } else {
        res.status(404).json({ error: 'Photo not found' });
    }
});

// Endpoint con i dettagli di una foto (date reali del file, dimensione, ecc.)
app.get('/api/photo/:id/info', async (req, res) => {
    const photo = db.prepare('SELECT * FROM photos WHERE id = ?').get(req.params.id);
    if (!photo) return res.status(404).json({ error: 'Photo not found' });

    let stats = null;
    try {
        stats = await fs.stat(photo.path);
    } catch (_) { /* file spostato o eliminato */ }

    res.json({
        ...photo,
        exists: !!stats,
        size: stats ? stats.size : photo.size,
        file_created_at: stats ? stats.birthtime.toISOString() : null,
        file_modified_at: stats ? stats.mtime.toISOString() : null,
        // created_at di SQLite è in UTC senza fuso: lo convertiamo in ISO
        added_at: photo.created_at ? new Date(photo.created_at.replace(' ', 'T') + 'Z').toISOString() : null,
    });
});

// Endpoint per salvare un'immagine modificata (ritaglio/rotazione fatti dall'app)
// Query: mode=copy|overwrite, ext=jpg|png|...  Body: byte dell'immagine (application/octet-stream)
app.post('/api/photo/:id/edit', express.raw({ type: '*/*', limit: '200mb' }), async (req, res) => {
    const photo = db.prepare('SELECT * FROM photos WHERE id = ?').get(req.params.id);
    if (!photo) return res.status(404).json({ error: 'Photo not found' });
    if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
        return res.status(400).json({ error: 'Empty image' });
    }

    const originalExt = path.extname(photo.path).toLowerCase();
    let outExt = '.' + String(req.query.ext || originalExt).replace('.', '').toLowerCase();
    if (!IMAGE_EXTENSIONS.includes(outExt)) outExt = originalExt;

    try {
        if (req.query.mode === 'overwrite') {
            if (outExt !== originalExt) {
                return res.status(400).json({ error: 'Cannot overwrite with a different format' });
            }
            await fs.writeFile(photo.path, req.body);
            db.prepare('UPDATE photos SET size = ? WHERE id = ?').run(req.body.length, photo.id);
            return res.json(db.prepare('SELECT * FROM photos WHERE id = ?').get(photo.id));
        }

        // Salva come copia nella stessa cartella: nome_modificata.jpg, nome_modificata_2.jpg, ...
        const dir = path.dirname(photo.path);
        const base = path.basename(photo.path, path.extname(photo.path));
        let target;
        let i = 1;
        do {
            target = path.join(dir, `${base}_modificata${i > 1 ? '_' + i : ''}${outExt}`);
            i++;
        } while (fs.existsSync(target));

        await fs.writeFile(target, req.body);
        insertPhoto.run(path.basename(target), target, req.body.length, `image/${outExt.replace('.', '')}`);
        res.json(db.prepare('SELECT * FROM photos WHERE path = ?').get(target));
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to save image' });
    }
});

// Endpoint to get all settings as { key: value }
app.get('/api/settings', (req, res) => {
    res.json(getAllSettings());
});

// Endpoint to get a setting
app.get('/api/settings/:key', (req, res) => {
    const { key } = req.params;
    const setting = getSetting(key);
    res.json(setting || { value: null });
});

// Endpoint to update a setting
app.post('/api/settings', (req, res) => {
    const { key, value } = req.body;
    if (!key) return res.status(400).json({ error: 'Missing key' });
    updateSetting(key, String(value));
    res.json({ success: true });
});

app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
});
