#!/bin/bash

DB_USER="root"
DB_PASS="root_password"
DB_NAME="fraud_detection"
DB_PORT="3307"

ADMIN_USER="admin"
ADMIN_PASS="secret123"

main_menu() {
  echo ""
  echo "====== TRANSACTION SYSTEM CLI ======"
  echo "1. Create User"
  echo "2. View Users"
  echo "3. Make Transaction"
  echo "4. Admin Login"
  echo "5. Exit"
  echo "===================================="
  read -p "Enter choice: " choice
}

admin_dashboard() {
  while true; do
    echo ""
    echo "====== ADMIN DASHBOARD ======"
    echo "1. Check Fraud Rules"
    echo "2. View Fraud Alerts"
    echo "3. Export Fraud Alerts to CSV"
    echo "4. View System Metrics"
    echo "5. Logout"
    echo "============================="
    read -p "Enter admin choice: " ach

    case $ach in
      1) check_fraud ;;
      2) view_alerts ;;
      3) export_alerts ;;
      4) view_metrics ;;
      5) echo "👋 Logged out from admin." && break ;;
      *) echo "❌ Invalid choice." ;;
    esac
  done
}

create_user() {
  read -p "Enter name: " name
  read -p "Enter email: " email
  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "INSERT INTO users (name, email) VALUES ('$name', '$email');"
  echo "✅ User '$name' created."
}

view_users() {
  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "SELECT id, name, email, created_at FROM users;"
}

make_transaction() {
  read -p "Enter email: " email
  read -p "Enter amount: " amount

  user_id=$(mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -sse \
    "SELECT id FROM users WHERE email='$email';")

  if [ -z "$user_id" ]; then
    echo "❌ User not found."
    return
  fi

  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "INSERT INTO transactions (user_id, amount) VALUES ($user_id, $amount);"

  echo "✅ Transaction of $amount added for $email."
}

check_fraud() {
  echo "🚨 Checking transactions above 10000..."
  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "UPDATE transactions
     SET is_fraud = TRUE
     WHERE amount > 10000 AND is_fraud = FALSE;

     INSERT INTO fraud_alerts (transaction_id, reason, flagged_at)
     SELECT t.id, 'High-value transaction over ₹10,000',t.timestamp
     FROM transactions t
    #  JOIN users u ON t.user_id = u.id
     WHERE t.amount > 10000
     AND NOT EXISTS (
      SELECT 1 FROM fraud_alerts f WHERE f.transaction_id = t.id
    );


    SELECT t.id, u.name, t.amount, t.timestamp
    FROM transactions t
    JOIN users u ON t.user_id = u.id
    WHERE t.amount > 10000;"

  echo ""

# Rule 2: More than 3 transactions in 2-minute interval
  echo "🚨 Users with > 3 transactions in the last 2 minutes:"
  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e "
    -- Step 1: Flag fraudulent transactions
    UPDATE transactions
    SET is_fraud = TRUE
    WHERE timestamp >= NOW() - INTERVAL 2 MINUTE
    AND user_id IN (
        SELECT user_id FROM (
        SELECT user_id
        FROM transactions
        WHERE timestamp >= NOW() - INTERVAL 2 MINUTE
        GROUP BY user_id
        HAVING COUNT(*) > 3
        ) AS temp_users
    )
    AND is_fraud = FALSE;

    -- Step 2: Insert into fraud_alerts
    INSERT INTO fraud_alerts (transaction_id, reason)
    SELECT t.id, 'More than 3 transactions in 2 minutes'
    FROM transactions t
    WHERE t.timestamp >= NOW() - INTERVAL 2 MINUTE
    AND t.user_id IN (
        SELECT user_id FROM (
        SELECT user_id
        FROM transactions
        WHERE timestamp >= NOW() - INTERVAL 2 MINUTE
        GROUP BY user_id
        HAVING COUNT(*) > 3
        ) AS temp_users
    )
    AND NOT EXISTS (
        SELECT 1 FROM fraud_alerts f WHERE f.transaction_id = t.id
    );

    -- Step 3: Output flagged users and their transaction counts
    SELECT u.name, COUNT(*) AS tx_count
    FROM transactions t
    JOIN users u ON t.user_id = u.id
    WHERE t.timestamp >= NOW() - INTERVAL 2 MINUTE
    GROUP BY t.user_id
    HAVING tx_count > 3;
    "

}

view_alerts() {
  echo "📋 Viewing all fraud alerts..."
  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "SELECT * FROM fraud_alerts;"
}

export_alerts() {
  echo "📤 Exporting fraud alerts to fraud_alerts.csv..."
  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "SELECT * FROM fraud_alerts;" > fraud_alerts.csv
  echo "✅ Exported to fraud_alerts.csv"
}

view_metrics() {
  echo "📊 System Metrics:"
  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "-- Total Users
    SELECT 'Total Users' AS metric, COUNT(*) AS value FROM users
    UNION
    -- Total Transactions
    SELECT 'Total Transactions', COUNT(*) FROM transactions
    UNION
    -- Total Fraud Transactions
    SELECT 'Fraud Transactions', COUNT(*) FROM transactions WHERE is_fraud = TRUE
    UNION
    -- % Fraud
    SELECT 'Fraud %', ROUND((SELECT COUNT(*) FROM transactions WHERE is_fraud = TRUE) * 100.0 / 
                           (SELECT COUNT(*) FROM transactions), 2)
    UNION
    -- Simulated Avg Response Time (in ms)
    SELECT 'Avg Response Time (ms)', ROUND(RAND() * 100 + 50, 2)
    UNION
    -- Health status logic (simple rule: if >10% fraud, degraded)
    SELECT 'System Health', 
      CASE 
        WHEN (SELECT COUNT(*) FROM transactions WHERE is_fraud = TRUE) * 100.0 /
             (SELECT COUNT(*) FROM transactions) > 10 THEN 'Degraded'
        ELSE 'Healthy'
      END;
  "
}

admin_login() {
  read -p "Enter admin username: " user
  read -sp "Enter admin password: " pass
  echo ""
  if [[ "$user" == "$ADMIN_USER" && "$pass" == "$ADMIN_PASS" ]]; then
    echo "✅ Admin login successful."
    admin_dashboard
  else
    echo "❌ Invalid admin credentials."
  fi
}

while true; do
  main_menu
  case $choice in
    1) create_user ;;
    2) view_users ;;
    3) make_transaction ;;
    4) admin_login ;;
    5) echo "👋 Exiting..." && break ;;
    *) echo "❌ Invalid choice." ;;
  esac
done
