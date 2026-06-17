const express = require('express');
const router = express.Router();
const pool = require('../config/db');

// Get all accounts for logged in user
router.get('/', async (req, res) => {
    const { uid } = req.user;
    
    try {
        const [userRows] = await pool.query('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (userRows.length === 0) return res.status(404).json({ error: 'User not found' });
        
        const userId = userRows[0].id;
        const [accounts] = await pool.query('SELECT * FROM accounts WHERE user_id = ?', [userId]);
        res.json(accounts);
    } catch (error) {
        console.error('Error fetching accounts:', error.message);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Create new account
router.post('/', async (req, res) => {
    const { uid } = req.user;
    const { name, type, currency, balance } = req.body;
    
    try {
        const [userRows] = await pool.query('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (userRows.length === 0) return res.status(404).json({ error: 'User not found' });
        
        const userId = userRows[0].id;
        const [result] = await pool.query(
            'INSERT INTO accounts (user_id, name, type, currency, balance) VALUES (?, ?, ?, ?, ?)',
            [userId, name, type, currency, balance || 0]
        );
        
        res.status(201).json({ id: result.insertId, name, type, currency, balance });
    } catch (error) {
        console.error('Error creating account:', error.message);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Get account summary (Total balance, income, expense)
router.get('/summary', async (req, res) => {
    const { uid } = req.user;
    
    try {
        const [userRows] = await pool.query('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (userRows.length === 0) return res.status(404).json({ error: 'User not found' });
        
        const userId = userRows[0].id;
        
        const [summary] = await pool.query(
            `SELECT 
                SUM(balance) as totalBalance,
                (SELECT SUM(amount) FROM transactions WHERE user_id = ? AND type = 'Income') as totalIncome,
                (SELECT SUM(amount) FROM transactions WHERE user_id = ? AND type = 'Expense') as totalExpense
            FROM accounts WHERE user_id = ?`,
            [userId, userId, userId]
        );
        
        res.json({
            totalBalance: summary[0].totalBalance || 0,
            totalIncome: summary[0].totalIncome || 0,
            totalExpense: summary[0].totalExpense || 0
        });
    } catch (error) {
        console.error('Error fetching account summary:', error.message);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Delete an account
router.delete('/:id', async (req, res) => {
    const { uid } = req.user;
    const { id } = req.params;

    try {
        const [userRows] = await pool.query('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (userRows.length === 0) return res.status(404).json({ error: 'User not found' });
        
        const userId = userRows[0].id;
        
        await pool.query('DELETE FROM accounts WHERE id = ? AND user_id = ?', [id, userId]);
        res.json({ message: 'Account deleted successfully' });
    } catch (error) {
        console.error('Error deleting account:', error.message);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

module.exports = router;
