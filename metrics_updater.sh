#!/bin/bash

DB_USER="root"
DB_PASS="root_password"
DB_NAME="fraud_detection"
DB_PORT="3307"

echo "📊 Updating system metrics..."

# Total transactions
total_tx=$(mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -sse \
  "SELECT COUNT(*) FROM Transactions;")

# Average transaction amount
avg_tx=$(mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -sse \
  "SELECT AVG(amount) FROM Transactions;")

# Fake response time (for demo), you can later replace with real ping/time logic
response_time=$(awk -v min=0.1 -v max=1 'BEGIN{srand(); print min+rand()*(max-min)}')

# Insert metrics
mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
  "INSERT INTO Metrics (metric_name, value) VALUES 
    ('Total Transactions', $total_tx),
    ('Average Transaction Amount', $avg_tx);"

# Insert health check metric
mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
  "INSERT INTO HealthChecks (response_time) VALUES ($response_time);"

echo "✅ Metrics updated successfully!"
