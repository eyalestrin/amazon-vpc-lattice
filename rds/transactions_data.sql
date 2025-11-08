-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    transaction_date TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample transaction data
INSERT INTO transactions (customer_id, product_name, amount, transaction_date) VALUES
(1001, 'Laptop Computer', 1299.99, '2024-01-15 10:30:00'),
(1002, 'Wireless Mouse', 29.99, '2024-01-15 11:45:00'),
(1003, 'USB-C Cable', 19.99, '2024-01-15 14:20:00'),
(1001, 'External Monitor', 299.99, '2024-01-16 09:15:00'),
(1004, 'Keyboard', 79.99, '2024-01-16 13:30:00'),
(1002, 'Webcam', 89.99, '2024-01-17 16:45:00'),
(1005, 'Headphones', 149.99, '2024-01-17 18:20:00'),
(1003, 'Phone Charger', 24.99, '2024-01-18 12:10:00'),
(1006, 'Tablet', 399.99, '2024-01-18 15:30:00'),
(1004, 'Bluetooth Speaker', 59.99, '2024-01-19 11:20:00'),
(1007, 'Smart Watch', 249.99, '2024-01-19 14:45:00'),
(1005, 'Power Bank', 39.99, '2024-01-20 10:15:00'),
(1008, 'Gaming Mouse', 69.99, '2024-01-20 16:30:00'),
(1006, 'Screen Protector', 12.99, '2024-01-21 13:20:00'),
(1009, 'Wireless Earbuds', 129.99, '2024-01-21 17:45:00');

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_transactions_customer_id ON transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date);

-- Display inserted data
SELECT COUNT(*) as total_transactions FROM transactions;