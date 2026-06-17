-- Finloop Database Schema

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    firebase_uid VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) NOT NULL,
    display_name VARCHAR(255),
    default_currency VARCHAR(10) DEFAULT 'USD',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS accounts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    type ENUM('Cash', 'Bank Account', 'Wallet', 'Credit Card') NOT NULL,
    currency VARCHAR(10) NOT NULL,
    balance DECIMAL(15, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    type ENUM('Income', 'Expense') NOT NULL,
    icon VARCHAR(50),
    color VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    account_id INT NOT NULL,
    category_id INT,
    amount DECIMAL(15, 2) NOT NULL,
    type ENUM('Income', 'Expense', 'Transfer') NOT NULL,
    date DATETIME DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    to_account_id INT, -- Only for Transfer type
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
    FOREIGN KEY (to_account_id) REFERENCES accounts(id) ON DELETE SET NULL
);

-- Default categories for new users
INSERT INTO categories (user_id, name, type, icon, color) VALUES 
(0, 'Salary', 'Income', 'money', '#4CAF50'),
(0, 'Business', 'Income', 'business', '#2196F3'),
(0, 'Food', 'Expense', 'restaurant', '#FF5722'),
(0, 'Travel', 'Expense', 'flight', '#9C27B0'),
(0, 'Shopping', 'Expense', 'shopping_cart', '#E91E63'),
(0, 'Health', 'Expense', 'medical_services', '#F44336');
-- Note: user_id 0 can be a template for cloning categories to new users.
