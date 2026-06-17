const express = require('express');
const router = express.Router();
const pool = require('../config/db');

// Get user settings
router.get('/settings', async (req, res) => {
    const { uid } = req.user;
    try {
        const [rows] = await pool.query(
            'SELECT default_currency, theme_mode FROM users WHERE firebase_uid = ?',
            [uid]
        );
        if (rows.length === 0) return res.status(404).json({ error: 'User not found' });
        res.json(rows[0]);
    } catch (error) {
        console.error('Error fetching settings:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Update user settings
router.put('/settings', async (req, res) => {
    const { uid } = req.user;
    const { default_currency, theme_mode } = req.body;
    
    try {
        await pool.query(
            'UPDATE users SET default_currency = COALESCE(?, default_currency), theme_mode = COALESCE(?, theme_mode) WHERE firebase_uid = ?',
            [default_currency, theme_mode, uid]
        );
        res.json({ message: 'Settings updated successfully' });
    } catch (error) {
        console.error('Error updating settings:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

module.exports = router;
