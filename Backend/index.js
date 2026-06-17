const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const pool = require('./config/db');
const { verifyToken } = require('./middleware/auth');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Request logging middleware
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    next();
});

// Routes
app.get('/', (req, res) => {
    res.json({ message: 'Finloop API is running' });
});

// Auth & User Sync Route
app.post('/api/auth/sync', verifyToken, async (req, res) => {
    const { uid, email, name } = req.user;

    try {
        // Check if user exists
        const [rows] = await pool.query('SELECT * FROM users WHERE firebase_uid = ?', [uid]);

        if (rows.length === 0) {
            // Create new user
            const [result] = await pool.query(
                'INSERT INTO users (firebase_uid, email, display_name) VALUES (?, ?, ?)',
                [uid, email, name || '']
            );

            // Add default categories for new user
            await pool.query(
                'INSERT INTO categories (user_id, name, type, icon, color) ' +
                'SELECT ?, name, type, icon, color FROM categories WHERE user_id = 0',
                [result.insertId]
            );

            return res.status(201).json({ message: 'User created and synced', userId: result.insertId });
        }

        res.json({ message: 'User synced', userId: rows[0].id });
    } catch (error) {
        console.error('Error syncing user:', error.message);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Accounts Route
app.use('/api/accounts', verifyToken, require('./routes/accounts'));

// Transactions Route
app.use('/api/transactions', verifyToken, require('./routes/transactions'));

// Categories Route
app.use('/api/categories', verifyToken, require('./routes/categories'));

// Users Settings Route
app.use('/api/users', verifyToken, require('./routes/users'));

// Start Server
app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
