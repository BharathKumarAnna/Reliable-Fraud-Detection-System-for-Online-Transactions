#!/bin/bash

DB_USER="root"
DB_NAME="fraud_detection"
DB_PASS="root_password"
DB_PORT="3307"

menu() {
  echo ""
  echo "====== TRANSACTION SYSTEM CLI ======"
  echo "1. Create User"
  echo "2. View Users"
  echo "3. Make Transaction"
  echo "4. Admin - Check Fraud"
  echo "5. Exit"
  echo "===================================="
  read -p "Enter choice: " choice
}

create_user() {
  read -p "Enter username: " username
  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "INSERT INTO users (username) VALUES ('$username');"
  echo "✅ User '$username' created."
}

view_users() {
  mysql -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "SELECT id, username, balance FROM users;"
}

make_transaction() {
  read -p "Enter username: " username
  read -p "Enter amount: " amount

  user_id=$(mysql -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -sse \
    "SELECT id FROM users WHERE username='$username';")

  if [ -z "$user_id" ]; then
    echo "❌ User not found."
    return
  fi

  mysql -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "INSERT INTO transactions (user_id, amount) VALUES ($user_id, $amount);
     UPDATE users SET balance = balance + $amount WHERE id = $user_id;"
  echo "✅ Transaction completed."
}

check_fraud() {
  echo "🔍 Running fraud detection rules..."

  echo "🚨 Transactions above 10000:"
  mysql -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "SELECT t.id, u.username, t.amount, t.created_at
     FROM transactions t
     JOIN users u ON t.user_id = u.id
     WHERE t.amount > 10000;"

  echo ""
  echo "🚨 Users with more than 3 transactions in 1 minute:"
  mysql -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "SELECT u.username, COUNT(*) as tx_count
     FROM transactions t
     JOIN users u ON t.user_id = u.id
     WHERE t.created_at >= NOW() - INTERVAL 1 MINUTE
     GROUP BY t.user_id
     HAVING tx_count > 3;"
}

while true; do
  menu
  case $choice in
    1) create_user ;;
    2) view_users ;;
    3) make_transaction ;;
    4) check_fraud ;;
    5) echo "Exiting..." && break ;;
    *) echo "❌ Invalid choice." ;;
  esac
done
