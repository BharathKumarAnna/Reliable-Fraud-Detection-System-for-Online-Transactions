#!/bin/bash

DB_USER="root"
DB_PASS="root"  
DB_PORT="3306"
DB_NAME="fraud_detection"

LOGGED_IN=false
CURRENT_USER=""
CURRENT_USER_ID=""

main_menu() {
  echo ""
  echo "===== WELCOME TO TRANSACTION SYSTEM ====="
  echo "1. Sign In (New User)"
  echo "2. Login (Existing User)"
  echo "3. Exit"
  echo "==========================================="
  read -p "Enter choice: " choice
}

dashboard_menu() {
  echo ""
  echo "========== DASHBOARD =========="
  echo "1. View Users"
  echo "2. Make Transaction"
  echo "3. Check Fraud"
  echo "4. Logout"
  echo "5. Exit"
  echo "==============================="
  read -p "Enter choice: " dash_choice
}

sign_in() {
  read -p "Enter your name: " name
  read -p "Enter your email: " email

  # Check if email already exists
  existing_user=$(mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -sse \
    "SELECT COUNT(*) FROM users WHERE email='$email';")

  if [ "$existing_user" -gt 0 ]; then
    echo "❌ User already exists. Please login."
  else
    mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -e \
      "INSERT INTO users (name, email) VALUES ('$name', '$email');"
    echo "✅ User registered successfully. Please login."
  fi
}


login() {
  read -p "Enter email: " email
  CURRENT_USER_ID=$(mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -sse \
    "SELECT id FROM users WHERE email='$email';")
  if [ -z "$CURRENT_USER_ID" ]; then
    echo "❌ Login failed. User not found."
  else
    LOGGED_IN=true
    CURRENT_USER=$email
    echo "✅ Login successful. Welcome, $CURRENT_USER!"
  fi
}

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
  echo "\n🚨 Transactions above 10000:"
  mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -e \
    "SELECT t.id, u.name, t.amount, t.timestamp FROM transactions t JOIN users u ON t.user_id = u.id WHERE t.amount > 10000;"

  echo "\n🚨 Users with more than 3 transactions in 1 minute:"
  mysql -h127.0.0.1 -u"$DB_USER" -p"$DB_PASS" -P"$DB_PORT" -D"$DB_NAME" -e \
    "SELECT u.name, COUNT(*) as tx_count FROM transactions t JOIN users u ON t.user_id = u.id WHERE t.timestamp >= NOW() - INTERVAL 1 MINUTE GROUP BY t.user_id HAVING tx_count > 3;"
}

while true; do
  if ! $LOGGED_IN; then
    main_menu
    case $choice in
      1) sign_in ;;
      2) login ;;
      3) echo "Exiting..." && break ;;
      *) echo "❌ Invalid choice." ;;
    esac
  else
    dashboard_menu
    case $dash_choice in
      1) view_users ;;
      2) make_transaction ;;
      3) check_fraud ;;
      4) LOGGED_IN=false; CURRENT_USER=""; CURRENT_USER_ID=""; echo "🚪 Logged out." ;;
      5) echo "Exiting..." && break ;;
      *) echo "❌ Invalid choice." ;;
    esac
  fi
done
