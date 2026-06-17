const pool = require('./config/db');

async function updateSchema() {
    try {
        console.log('Updating schema for transfers...');
        
        // 1. Update transactions type enum
        await pool.query("ALTER TABLE transactions MODIFY COLUMN type ENUM('Income', 'Expense', 'Transfer') NOT NULL");
        console.log('Updated transaction type enum.');

        // 2. Update categories type enum
        await pool.query("ALTER TABLE categories MODIFY COLUMN type ENUM('Income', 'Expense', 'Transfer') NOT NULL");
        console.log('Updated category type enum.');

        // 3. Add to_account_id to transactions
        const [columns] = await pool.query("SHOW COLUMNS FROM transactions LIKE 'to_account_id'");
        if (columns.length === 0) {
            await pool.query("ALTER TABLE transactions ADD COLUMN to_account_id INT AFTER account_id");
            await pool.query("ALTER TABLE transactions ADD CONSTRAINT fk_to_account FOREIGN KEY (to_account_id) REFERENCES accounts(id)");
            console.log('Added to_account_id column.');
        } else {
            console.log('to_account_id column already exists.');
        }

        // 4. Add "Transfer" category to each user if it doesn't exist
        const [users] = await pool.query("SELECT id FROM users");
        for (const user of users) {
            const [cats] = await pool.query("SELECT * FROM categories WHERE user_id = ? AND name = 'Transfer'", [user.id]);
            if (cats.length === 0) {
                await pool.query("INSERT INTO categories (user_id, name, type, icon, color) VALUES (?, 'Transfer', 'Transfer', 'swap_horiz', '#757575')", [user.id]);
            }
        }
        console.log('Added Transfer category to existing users.');

        console.log('Schema update complete!');
        process.exit(0);
    } catch (error) {
        console.error('Error updating schema:', error.message);
        process.exit(1);
    }
}

updateSchema();
