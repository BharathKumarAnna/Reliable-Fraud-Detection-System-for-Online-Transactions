
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    phone_number VARCHAR(15) UNIQUE,
    email VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255),
    upi_id VARCHAR(50) UNIQUE,
    account_balance DECIMAL(10,2) DEFAULT 100000.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    amount DECIMAL(10,2),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_fraud BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (upi_id) REFERENCES users(upi_id)
);

CREATE TABLE fraud_alerts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id INT,
    reason TEXT,
    flagged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (transaction_id) REFERENCES transactions(id)
);

CREATE TABLE metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    metric_name VARCHAR(50),
    value FLOAT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE health_checks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    status ENUM('Healthy', 'Degraded', 'Down') DEFAULT 'Healthy',
    response_time FLOAT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_otp (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    otp_code VARCHAR(6),
    expires_at DATETIME,
    is_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);


-- CREATE TABLE users (
--     id INT AUTO_INCREMENT PRIMARY KEY,
--     name VARCHAR(100),
--     email VARCHAR(100) UNIQUE,
--     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );

-- CREATE TABLE transactions (
--     id INT AUTO_INCREMENT PRIMARY KEY,
--     user_id INT,
--     amount DECIMAL(10,2),
--     timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--     is_fraud BOOLEAN DEFAULT FALSE,
--     FOREIGN KEY (user_id) REFERENCES users(id)
-- );

-- CREATE TABLE fraud_alerts (
--     id INT AUTO_INCREMENT PRIMARY KEY,
--     transaction_id INT,
--     reason TEXT,
--     flagged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--     FOREIGN KEY (transaction_id) REFERENCES transactions(id)
-- );

-- CREATE TABLE metrics (
--     id INT AUTO_INCREMENT PRIMARY KEY,
--     metric_name VARCHAR(50),
--     value FLOAT,
--     timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );

-- CREATE TABLE health_checks (
--     id INT AUTO_INCREMENT PRIMARY KEY,
--     status ENUM('Healthy', 'Degraded', 'Down') DEFAULT 'Healthy',
--     response_time FLOAT,
--     timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );

