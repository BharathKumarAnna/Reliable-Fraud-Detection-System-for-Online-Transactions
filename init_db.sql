-- init_db.sql

CREATE DATABASE IF NOT EXISTS fraud_detection;

USE fraud_detection;

CREATE TABLE IF NOT EXISTS Users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS Transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    amount DECIMAL(10,2),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_fraud BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES Users(id)
);

CREATE TABLE IF NOT EXISTS FraudAlerts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id INT,
    reason TEXT,
    flagged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (transaction_id) REFERENCES Transactions(id)
);

CREATE TABLE IF NOT EXISTS Metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    metric_name VARCHAR(50),
    value FLOAT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS HealthChecks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    status ENUM('Healthy', 'Degraded', 'Down') DEFAULT 'Healthy',
    response_time FLOAT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
