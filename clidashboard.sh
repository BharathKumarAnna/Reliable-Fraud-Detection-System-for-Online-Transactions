#!/bin/bash

DB_USER="root"
DB_PASS="root_password"
DB_NAME="fraud_detection"
DB_PORT="3307"

ADMIN_USER="admin"
ADMIN_PASS="secret123"

USER_LOGGED_IN=false
USER_NAME=""
USER_PHONE=""
USER_ID=""

generate_upi_id() {
  local phone=$1
  echo "${phone}@rfd"
}

create_user_with_auth() {
  read -p "Enter name: " NAME
  read -p "Enter phone number: " PHONE
  read -p "Enter email: " EMAIL
  read -sp "Enter password: " PASSWORD
  echo

  HASHED_PASSWORD=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$PASSWORD', bcrypt.gensalt()).decode())")
  UPI_ID=$(generate_upi_id "$PHONE")

  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
  "
    INSERT INTO users (name, phone_number, email, password_hash, upi_id)
    VALUES ('$NAME', '$PHONE', '$EMAIL', '$HASHED_PASSWORD', '$UPI_ID');
  "

  USER_ID=$(mysql -h127.0.0.1 -N -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
  "
    SELECT id FROM users WHERE phone_number = '$PHONE';
  ")

  OTP=$((RANDOM % 900000 + 100000))
  EXPIRES_AT=$(date -v+5M '+%F %T')
#   EXPIRES_AT=$(date -d '+5 minutes' '+%F %T')


  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
  "
    INSERT INTO user_otp (user_id, otp_code, expires_at)
    VALUES ($USER_ID, '$OTP', '$EXPIRES_AT');
  "

  echo "📲 Your OTP is: $OTP"
  read -p "Enter OTP: " INPUT_OTP

  VALID=$(mysql -h127.0.0.1 -N -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
  "
   SELECT COUNT(*) FROM user_otp
   WHERE user_id = $USER_ID AND otp_code = '$INPUT_OTP'
   AND is_used = FALSE AND expires_at >= NOW();
  ")

  if [[ "$VALID" =~ ^[0-9]+$ && "$VALID" -eq 1 ]]; then
    echo "✅ OTP Verified!"
    # mark OTP used
  else
    echo "❌ Invalid or expired OTP. Signup failed."
    exit 1
  fi
}

login_user_with_auth() {
  read -p "Enter phone number: " PHONE
  read -sp "Enter password: " PASSWORD
  echo

  STORED_HASH=$(mysql -h127.0.0.1 -N -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
  "
    SELECT password_hash FROM users WHERE phone_number = '$PHONE';
  ")

python3 -c "
import bcrypt
import sys
password = b'$PASSWORD'
stored_hash = \"$STORED_HASH\".encode('utf-8')
if bcrypt.checkpw(password, stored_hash):
    sys.exit(0)
else:
    sys.exit(1)
"

  if [ $? -eq 0 ]; then
    USER_LOGGED_IN=true
    USER_PHONE=$PHONE
    USER_NAME=$(mysql -h127.0.0.1 -N -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "
      SELECT name FROM users WHERE phone_number = '$PHONE';
    ")
    USER_ID=$(mysql -h127.0.0.1 -N -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "
      SELECT id FROM users WHERE phone_number = '$PHONE';
    ")
    echo "✅ Login successful! Welcome, $USER_NAME"
  else
    echo "❌ Invalid credentials"
    exit 1
  fi
}

run_health_check() {
  echo "🚨 Running Health Check..."
  
  if [[ -f "./healthcheck.sh" ]]; then
    chmod +x healthcheck.sh
    bash ./healthcheck.sh
    echo "✅ Health Check completed at $(date)"
  else
    echo "❌ healthcheck.sh not found in the current directory."
  fi
}

# ---------------------------------- USERS BLOCK ------------------------------------

view_users() {
  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "SELECT id, name, phone_number, email, upi_id, created_at FROM users;"
}


# ----------------------------------- ADMIN BLOCK ------------------------------------
admin_dashboard() 
{
  while true; do
    echo ""
    echo "====== ADMIN DASHBOARD ======"
    echo "1. View Users"
    echo "2. Check Fraud Rules"
    echo "3. View Fraud Alerts"
    echo "4. Export Fraud Alerts to CSV"
    echo "5. View System Metrics"
    echo "6. run health check "
    echo "7. Logout"
    echo "============================="
    read -p "Enter admin choice: " ach

    case $ach in
      1) view_users ;;
      2) run_fraud_detection ;;
      3) view_alerts ;;
      4) export_alerts ;;
      5) view_metrics ;;
      6) run_health_check ;; 
      7) echo "👋 Logged out from admin." && break ;;
      *) echo "❌ Invalid choice." ;;
    esac
  done
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

# ------------------------------------ FRAUD DETECTION BLOCK ------------------------------------

run_fraud_detection() {
  echo "🚨 Running Fraud Detection..."
  echo "🚨 Checking transactions above 10000..."
  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "UPDATE transactions
     SET is_fraud = TRUE
     WHERE amount > 10000 AND is_fraud = FALSE;

     INSERT INTO fraud_alerts (transaction_id, reason, flagged_at)
     SELECT t.id, 'High-value transaction over ₹10,000',t.timestamp
     FROM transactions t
     WHERE t.amount > 10000
     AND NOT EXISTS (
      SELECT 1 FROM fraud_alerts f WHERE f.transaction_id = t.id
    );


    SELECT t.id, u.name, t.amount, t.timestamp
    FROM transactions t
    JOIN users u ON t.user_id = u.id
    WHERE t.amount > 10000;"

  echo ""

  echo "🚨 Users with > 3 transactions in the last 2 minutes:"
  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
  "
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

  echo "✅ Fraud detection completed at $(date)"
}

# ------------------------------------- ALERTS BLOCK ------------------------------------------


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

# --------------------------------------- TRANSACTION BLOCK --------------------------------------
# Add these to clidashboard.sh, after login is successful

make_transaction() {
  if [ "$USER_LOGGED_IN" != true ]; then
    echo "❌ Please login first."
    return
  fi

  read -p "Enter receiver UPI ID: " RECEIVER_UPI
  read -p "Enter amount to transfer: " AMOUNT

  RECEIVER_ID=$(mysql -h127.0.0.1 -N -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
  "SELECT id FROM users WHERE upi_id = '$RECEIVER_UPI';")

  if [ -z "$RECEIVER_ID" ]; then
    echo "❌ Invalid UPI ID."
    return
  fi

  BALANCE=$(mysql -h127.0.0.1 -N -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
  "SELECT account_balance FROM users WHERE id = $USER_ID;")

  if (( $(echo "$BALANCE < $AMOUNT" | bc -l) )); then
    echo "❌ Insufficient balance."
    return
  fi

  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
  "START TRANSACTION;
   UPDATE users SET account_balance = account_balance - $AMOUNT WHERE id = $USER_ID;
   UPDATE users SET account_balance = account_balance + $AMOUNT WHERE id = $RECEIVER_ID;
   INSERT INTO transactions (user_id, amount, timestamp) VALUES ($USER_ID, $AMOUNT, NOW());
   COMMIT;"

  echo "✅ Transaction successful!"
}

check_balance() {
  if [ "$USER_LOGGED_IN" != true ]; then
    echo "❌ Please login first."
    return
  fi

  BALANCE=$(mysql -h127.0.0.1 -N -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
  "SELECT account_balance FROM users WHERE id = $USER_ID;")

  echo "💰 Your current balance is: ₹$BALANCE"
}


# ------------------------------------ MAIN BLOCK ----------------------------------------

while true; do
  if [ "$USER_LOGGED_IN" = false ]; then
    echo -e "\\n📋 MENU:"
    echo "1. Sign Up"
    echo "2. Login"
    echo "3. Exit"
    echo "4. Admin Login"
    read -p "Choose an option: " CHOICE

    case $CHOICE in
      1) create_user_with_auth ;;
      2) login_user_with_auth ;;
      3) echo "👋 Goodbye!"; exit 0 ;;
      4) admin_login ;;
      *) echo "❌ Invalid option" ;;
    esac
  else
    echo -e "\\n📋 MAIN MENU (Logged in as $USER_NAME):"
    echo "1. Make Transaction"
    echo "2. Logout"
    echo "3. View Balance"
    read -p "Choose an option: " CHOICE

    case $CHOICE in
      1) make_transaction ;;
      2) 
        echo "🔓 Logging out..."
        USER_LOGGED_IN=false
        USER_NAME=""
        USER_PHONE=""
        USER_ID=""
        ;;
      3) check_balance ;; 
      *) echo "❌ Invalid option" ;;
    esac

  fi
done