const express = require('express');
const router = express.Router();
const pool = require('../config/db');

// Get all transactions for logged in user
router.get('/', async (req, res) => {
    const { uid } = req.user;
    
    try {
        const [userRows] = await pool.query('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (userRows.length === 0) return res.status(404).json({ error: 'User not found' });
        
        const userId = userRows[0].id;
        
        const [transactions] = await pool.query(
            'SELECT t.*, a.name as account_name, a2.name as to_account_name, c.name as category_name, c.icon as category_icon, c.color as category_color ' +
            'FROM transactions t ' +
            'LEFT JOIN accounts a ON t.account_id = a.id ' +
            'LEFT JOIN accounts a2 ON t.to_account_id = a2.id ' +
            'LEFT JOIN categories c ON t.category_id = c.id ' +
            'WHERE t.user_id = ? ' +
            'ORDER BY t.date DESC',
            [userId]
        );
        
        res.json(transactions);
    } catch (error) {
        console.error('Error fetching transactions:', error.message);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Create new transaction
router.post('/', async (req, res) => {
    const { uid } = req.user;
    const { account_id, category_id, amount, type, date, notes } = req.body;
    
    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();

        const [userRows] = await connection.query('SELECT id FROM users WHERE firebase_uid = ?', [uid]);
        if (userRows.length === 0) {
            await connection.rollback();
            return res.status(404).json({ error: 'User not found' });
        }
        
        const userId = userRows[0].id;

        // 1. Insert Transaction
        const [result] = await connection.query(
            'INSERT INTO transactions (user_id, account_id, to_account_id, category_id, amount, type, date, notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [userId, account_id, type === 'Transfer' ? req.body.to_account_id : null, category_id, amount, type, date || new Date(), notes]
        );

        // 2. Update Account Balance
        if (type === 'Transfer') {
            const to_account_id = req.body.to_account_id;
            if (!to_account_id) throw new Error('To Account is required for transfers');

            // Subtract from source
            await connection.query(
                'UPDATE accounts SET balance = balance - ? WHERE id = ? AND user_id = ?',
                [amount, account_id, userId]
            );
            // Add to destination
            await connection.query(
                'UPDATE accounts SET balance = balance + ? WHERE id = ? AND user_id = ?',
                [amount, to_account_id, userId]
            );
        } else {
            const balanceChange = type === 'Income' ? amount : -amount;
            await connection.query(
                'UPDATE accounts SET balance = balance + ? WHERE id = ? AND user_id = ?',
                [balanceChange, account_id, userId]
            );
        }

        await connection.commit();
        res.status(201).json({ id: result.insertId, ...req.body });
    } catch (error) {
        await connection.rollback();
        console.error('Error creating transaction:', error.message);
        res.status(500).json({ error: 'Internal Server Error' });
    } finally {
        connection.release();
    }
});

module.exports = router;
