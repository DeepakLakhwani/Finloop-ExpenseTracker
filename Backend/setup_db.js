const pool = require('./config/db');
const fs = require('fs');
const path = require('path');

async function setupDatabase() {
    try {
        const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
        const commands = schema.split(';').filter(cmd => cmd.trim().length > 0);
        
        console.log('Setting up database tables...');
        await pool.query('SET FOREIGN_KEY_CHECKS = 0');
        for (let command of commands) {
            await pool.query(command);
        }
        await pool.query('SET FOREIGN_KEY_CHECKS = 1');
        console.log('Database setup successful!');
        process.exit(0);
    } catch (error) {
        console.error('Error setting up database:', error.message);
        process.exit(1);
    }
}

setupDatabase();
