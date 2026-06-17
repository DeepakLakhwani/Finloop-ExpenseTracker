const express = require('express');
const router = express.Router();
const pool = require('../config/db');

// Get all categories for logged in user
router.get('/', async (req, res) => {
    const { uid } = req.user;
    
    try {
        const [userRows] = await pool.query('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (userRows.length === 0) return res.status(404).json({ error: 'User not found' });
        
        const userId = userRows[0].id;
        const [categories] = await pool.query('SELECT * FROM categories WHERE user_id = ? OR user_id = 0', [userId]);
        res.json(categories);
    } catch (error) {
        console.error('Error fetching categories:', error.message);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

module.exports = router;
