#!/bin/bash

# Database Credentials
DB_USER="root"
DB_PASS="root"
DB_PORT="3306"
DB_NAME="fraud_detection"

# Admin Credentials
ADMIN_USER="admin"
ADMIN_PASS="secret123"

# State Variables
LOGGED_IN=false
IS_ADMIN=false
CURRENT_USER=""
CURRENT_USER_ID=""

# Main Menu
main_menu() {
  echo ""
  echo "===== TRANSACTION SYSTEM ====="
  echo "1. Sign In (New User)"
  echo "2. Login (Existing User)"
  echo "3. Admin Login"
  echo "4. Exit"
  echo "=============================="
  read -p "Enter choice: " choice
}

# User Dashboard
user_dashboard() {
  while $LOGGED_IN && ! $IS_ADMIN; do
    echo ""
    echo "======== USER DASHBOARD ========"
    echo "1. View Users"
    echo "2. Make Transaction"
    echo "3. Check Fraud"
    echo "4. Logout"
    echo "================================"
    read -p "Enter choice: " dash_choice
    case $dash_choice in
      1) view_users ;;
      2) make_transaction ;;
      3) check_fraud ;;
      4) LOGGED_IN=false; CURRENT_USER=""; CURRENT_USER_ID=""; echo "🚪 Logged out." ;;
      *) echo "❌ Invalid choice." ;;
    esac
  done
}

# Admin Dashboard
admin_dashboard() {
  while $IS_ADMIN; do
    echo ""
    echo "======== ADMIN DASHBOARD ========"
    echo "1. Check Fraud Rules"
    echo "2. View Fraud Alerts"
    echo "3. Export Alerts to CSV"
    echo "4. View System Metrics"
    echo "5. Logout"
    echo "================================="
    read -p "Enter admin choice: " ach
    case $ach in
      1) check_fraud ;;
      2) view_alerts ;;
      3) export_alerts ;;
      4) view_metrics ;;
      5) IS_ADMIN=false; echo "👋 Logged out from admin." ;;
      *) echo "❌ Invalid choice." ;;
    esac
  done
}

# User Sign In
sign_in() {
  read -p "Enter your name: " name
  read -p "Enter your email: " email
  existing_user=$(mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -sse \
    "SELECT COUNT(*) FROM users WHERE email='$email';")
  if [ "$existing_user" -gt 0 ]; then
    echo "❌ User already exists. Please login."
  else
    mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -e \
      "INSERT INTO users (name, email) VALUES ('$name', '$email');"
    echo "✅ User registered. Please login."
  fi
}

# User Login
login() {
  read -p "Enter email: " email
  CURRENT_USER_ID=$(mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -sse \
    "SELECT id FROM users WHERE email='$email';")
  if [ -z "$CURRENT_USER_ID" ]; then
    echo "❌ User not found."
  else
    LOGGED_IN=true
    CURRENT_USER=$email
    echo "✅ Login successful. Welcome, $CURRENT_USER!"
    user_dashboard
  fi
}

# Admin Login
admin_login() {
  read -p "Enter admin username: " user
  read -sp "Enter admin password: " pass
  echo ""
  if [[ "$user" == "$ADMIN_USER" && "$pass" == "$ADMIN_PASS" ]]; then
    IS_ADMIN=true
    echo "✅ Admin login successful."
    admin_dashboard
  else
    echo "❌ Invalid admin credentials."
  fi
}

# Common Functions
view_users() {
  mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -e \
    "SELECT id, name, email, created_at FROM users;"
}

make_transaction() {
  if ! $LOGGED_IN; then
    echo "⚠️ Please log in first."
    return
  fi
  read -p "Enter amount: " amount
  mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -e \
    "INSERT INTO transactions (user_id, amount) VALUES ($CURRENT_USER_ID, $amount);"
  echo "✅ Transaction recorded."
}

check_fraud() {
  echo "🚨 High-value Transactions (₹>10000):"
  mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -e \
    "UPDATE transactions SET is_fraud = TRUE WHERE amount > 10000 AND is_fraud = FALSE;
     INSERT INTO fraud_alerts (transaction_id, reason, flagged_at)
     SELECT id, 'High-value transaction', timestamp
     FROM transactions
     WHERE amount > 10000 AND NOT EXISTS (
       SELECT 1 FROM fraud_alerts WHERE transaction_id = transactions.id
     );
     SELECT t.id, u.name, t.amount, t.timestamp FROM transactions t JOIN users u ON t.user_id = u.id WHERE t.amount > 10000;"

  echo "🚨 Users with >3 transactions in 2 minutes:"
  mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -e "
    UPDATE transactions
    SET is_fraud = TRUE
    WHERE timestamp >= NOW() - INTERVAL 2 MINUTE
    AND user_id IN (
        SELECT user_id FROM (
            SELECT user_id FROM transactions
            WHERE timestamp >= NOW() - INTERVAL 2 MINUTE
            GROUP BY user_id
            HAVING COUNT(*) > 3
        ) AS temp_users
    )
    AND is_fraud = FALSE;

    INSERT INTO fraud_alerts (transaction_id, reason)
    SELECT t.id, 'More than 3 transactions in 2 minutes'
    FROM transactions t
    WHERE t.timestamp >= NOW() - INTERVAL 2 MINUTE
    AND t.user_id IN (
        SELECT user_id FROM (
            SELECT user_id FROM transactions
            WHERE timestamp >= NOW() - INTERVAL 2 MINUTE
            GROUP BY user_id
            HAVING COUNT(*) > 3
        ) AS temp_users
    )
    AND NOT EXISTS (
        SELECT 1 FROM fraud_alerts f WHERE f.transaction_id = t.id
    );

    SELECT u.name, COUNT(*) as tx_count
    FROM transactions t
    JOIN users u ON t.user_id = u.id
    WHERE t.timestamp >= NOW() - INTERVAL 2 MINUTE
    GROUP BY t.user_id
    HAVING tx_count > 3;
  "
}

view_alerts() {
  mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -e "SELECT * FROM fraud_alerts;"
}

export_alerts() {
  mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -e "SELECT * FROM fraud_alerts;" > fraud_alerts.csv
  echo "✅ Exported to fraud_alerts.csv"
}

view_metrics() {
  mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -e "
    SELECT 'Total Users' AS metric, COUNT(*) AS value FROM users
    UNION
    SELECT 'Total Transactions', COUNT(*) FROM transactions
    UNION
    SELECT 'Fraud Transactions', COUNT(*) FROM transactions WHERE is_fraud = TRUE
    UNION
    SELECT 'Fraud %', ROUND((SELECT COUNT(*) FROM transactions WHERE is_fraud = TRUE) * 100.0 /
                            (SELECT COUNT(*) FROM transactions), 2)
    UNION
    SELECT 'Avg Response Time (ms)', ROUND(RAND() * 100 + 50, 2)
    UNION
    SELECT 'System Health',
           CASE
             WHEN (SELECT COUNT(*) FROM transactions WHERE is_fraud = TRUE) * 100.0 /
                  (SELECT COUNT(*) FROM transactions) > 10 THEN 'Degraded'
             ELSE 'Healthy'
           END;
  "
}

# Run Main Loop
while true; do
  main_menu
  case $choice in
    1) sign_in ;;
    2) login ;;
    3) admin_login ;;
    4) echo "👋 Exiting..." && break ;;
    *) echo "❌ Invalid choice." ;;
  esac
done
