const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs-extra');
const { insertPhoto, getPhotosFiltered, getSetting, updateSetting } = require('./db');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// Endpoint to scan a directory
app.post('/api/scan', async (req, res) => {
    const { folderPath } = req.body;

    if (!folderPath || !fs.existsSync(folderPath)) {
        return res.status(400).json({ error: 'Invalid folder path' });
    }

    try {
        const files = await fs.readdir(folderPath);
        const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];

        const photosFound = [];

        for (const file of files) {
            const ext = path.extname(file).toLowerCase();
            if (imageExtensions.includes(ext)) {
                const fullPath = path.join(folderPath, file);
                const stats = await fs.stat(fullPath);

                insertPhoto.run(file, fullPath, stats.size, `image/${ext.replace('.', '')}`);
                photosFound.push({ name: file, path: fullPath });
            }
        }

        res.json({ message: `Scanned ${photosFound.length} photos`, count: photosFound.length });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to scan directory' });
    }
});

// Endpoint to get photos with filtering/sorting
app.get('/api/photos', (req, res) => {
    const { name, sortBy, order } = req.query;
    const photos = getPhotosFiltered({ name, sortBy, order });
    res.json(photos);
});

// Endpoint to serve the image file
app.get('/api/photo/:id', (req, res) => {
    const { id } = req.params;
    const { db } = require('./db');
    const photo = db.prepare('SELECT path FROM photos WHERE id = ?').get(id);

    if (photo && fs.existsSync(photo.path)) {
        res.sendFile(photo.path);
    } else {
        res.status(404).json({ error: 'Photo not found' });
    }
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
    updateSetting(key, value);
    res.json({ success: true });
});

app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
});
