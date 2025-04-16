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
admin_dashboard() {
  while true; do
    echo ""
    echo "====== ADMIN DASHBOARD ======"
    echo "1. View Users"
    echo "2. Check Fraud Rules"
    echo "3. View Fraud Alerts"
    echo "4. Export Fraud Alerts to CSV"
    echo "5. View System Metrics"
    echo "6. Logout"
    echo "============================="
    read -p "Enter admin choice: " ach

    case $ach in
      1) view_users ;;
      2) run_fraud_detection ;;
      3) view_alerts ;;
      4) export_alerts ;;
      5) view_metrics ;;
      6) echo "👋 Logged out from admin." && break ;;
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
make_transaction() {
  read -p "Enter upi id: " upi_id
  read -p "Enter amount: " amount

  user_id=$(mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -sse \
    "SELECT id FROM users WHERE upi_id='$UPI_ID';")

  if [ -z "$user_id" ]; then
    echo "❌ User not found."
    return
  fi

  mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
    "INSERT INTO transactions (user_id, amount) VALUES ($user_id, $amount);"

  echo "✅ Transaction of $amount added for $UPI_ID."
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
    echo "1. Run Health Check"
    echo "2. Run Fraud Detection"
    echo "3. Logout"
    echo "4. Make Transaction"
    read -p "Choose an option: " CHOICE

    case $CHOICE in
      1) run_health_check ;;
      2) run_fraud_detection ;;
      3) 
        echo "🔓 Logging out..."
        USER_LOGGED_IN=false
        USER_NAME=""
        USER_PHONE=""
        USER_ID=""
        ;;
      4) make_transaction ;;
      *) echo "❌ Invalid option" ;;
    esac
  fi
done

# #!/bin/bash

# DB_USER="root"
# DB_PASS="root_password"
# DB_NAME="fraud_detection"
# DB_PORT="3307"

# ADMIN_USER="admin"
# ADMIN_PASS="secret123"

# main_menu() {
#   echo ""
#   echo "====== TRANSACTION SYSTEM CLI ======"
#   echo "1. Create User"
#   echo "2. View Users"
#   echo "3. Make Transaction"
#   echo "4. Admin Login"
#   echo "5. Exit"
#   echo "===================================="
#   read -p "Enter choice: " choice
# }

# admin_dashboard() {
#   while true; do
#     echo ""
#     echo "====== ADMIN DASHBOARD ======"
#     echo "1. Check Fraud Rules"
#     echo "2. View Fraud Alerts"
#     echo "3. Export Fraud Alerts to CSV"
#     echo "4. View System Metrics"
#     echo "5. Logout"
#     echo "============================="
#     read -p "Enter admin choice: " ach

#     case $ach in
#       1) check_fraud ;;
#       2) view_alerts ;;
#       3) export_alerts ;;
#       4) view_metrics ;;
#       5) echo "👋 Logged out from admin." && break ;;
#       *) echo "❌ Invalid choice." ;;
#     esac
#   done
# }

# create_user() {
#   read -p "Enter name: " name
#   read -p "Enter email: " email
#   mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
#     "INSERT INTO users (name, email) VALUES ('$name', '$email');"
#   echo "✅ User '$name' created."
# }

# view_users() {
#   mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
#     "SELECT id, name, email, created_at FROM users;"
# }

# make_transaction() {
#   read -p "Enter email: " email
#   read -p "Enter amount: " amount

#   user_id=$(mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -sse \
#     "SELECT id FROM users WHERE email='$email';")

#   if [ -z "$user_id" ]; then
#     echo "❌ User not found."
#     return
#   fi

#   mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
#     "INSERT INTO transactions (user_id, amount) VALUES ($user_id, $amount);"

#   echo "✅ Transaction of $amount added for $email."
# }

# check_fraud() {
#   echo "🚨 Checking transactions above 10000..."
#   mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
#     "UPDATE transactions
#      SET is_fraud = TRUE
#      WHERE amount > 10000 AND is_fraud = FALSE;

#      INSERT INTO fraud_alerts (transaction_id, reason, flagged_at)
#      SELECT t.id, 'High-value transaction over ₹10,000',t.timestamp
#      FROM transactions t
#     #  JOIN users u ON t.user_id = u.id
#      WHERE t.amount > 10000
#      AND NOT EXISTS (
#       SELECT 1 FROM fraud_alerts f WHERE f.transaction_id = t.id
#     );


#     SELECT t.id, u.name, t.amount, t.timestamp
#     FROM transactions t
#     JOIN users u ON t.user_id = u.id
#     WHERE t.amount > 10000;"

#   echo ""

# # Rule 2: More than 3 transactions in 2-minute interval
#   echo "🚨 Users with > 3 transactions in the last 2 minutes:"
#   mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e "
#     -- Step 1: Flag fraudulent transactions
#     UPDATE transactions
#     SET is_fraud = TRUE
#     WHERE timestamp >= NOW() - INTERVAL 2 MINUTE
#     AND user_id IN (
#         SELECT user_id FROM (
#         SELECT user_id
#         FROM transactions
#         WHERE timestamp >= NOW() - INTERVAL 2 MINUTE
#         GROUP BY user_id
#         HAVING COUNT(*) > 3
#         ) AS temp_users
#     )
#     AND is_fraud = FALSE;

#     -- Step 2: Insert into fraud_alerts
#     INSERT INTO fraud_alerts (transaction_id, reason)
#     SELECT t.id, 'More than 3 transactions in 2 minutes'
#     FROM transactions t
#     WHERE t.timestamp >= NOW() - INTERVAL 2 MINUTE
#     AND t.user_id IN (
#         SELECT user_id FROM (
#         SELECT user_id
#         FROM transactions
#         WHERE timestamp >= NOW() - INTERVAL 2 MINUTE
#         GROUP BY user_id
#         HAVING COUNT(*) > 3
#         ) AS temp_users
#     )
#     AND NOT EXISTS (
#         SELECT 1 FROM fraud_alerts f WHERE f.transaction_id = t.id
#     );

#     -- Step 3: Output flagged users and their transaction counts
#     SELECT u.name, COUNT(*) AS tx_count
#     FROM transactions t
#     JOIN users u ON t.user_id = u.id
#     WHERE t.timestamp >= NOW() - INTERVAL 2 MINUTE
#     GROUP BY t.user_id
#     HAVING tx_count > 3;
#     "

# }

# view_alerts() {
#   echo "📋 Viewing all fraud alerts..."
#   mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
#     "SELECT * FROM fraud_alerts;"
# }

# export_alerts() {
#   echo "📤 Exporting fraud alerts to fraud_alerts.csv..."
#   mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
#     "SELECT * FROM fraud_alerts;" > fraud_alerts.csv
#   echo "✅ Exported to fraud_alerts.csv"
# }

# view_metrics() {
#   echo "📊 System Metrics:"
#   mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e \
#     "-- Total Users
#     SELECT 'Total Users' AS metric, COUNT(*) AS value FROM users
#     UNION
#     -- Total Transactions
#     SELECT 'Total Transactions', COUNT(*) FROM transactions
#     UNION
#     -- Total Fraud Transactions
#     SELECT 'Fraud Transactions', COUNT(*) FROM transactions WHERE is_fraud = TRUE
#     UNION
#     -- % Fraud
#     SELECT 'Fraud %', ROUND((SELECT COUNT(*) FROM transactions WHERE is_fraud = TRUE) * 100.0 / 
#                            (SELECT COUNT(*) FROM transactions), 2)
#     UNION
#     -- Simulated Avg Response Time (in ms)
#     SELECT 'Avg Response Time (ms)', ROUND(RAND() * 100 + 50, 2)
#     UNION
#     -- Health status logic (simple rule: if >10% fraud, degraded)
#     SELECT 'System Health', 
#       CASE 
#         WHEN (SELECT COUNT(*) FROM transactions WHERE is_fraud = TRUE) * 100.0 /
#              (SELECT COUNT(*) FROM transactions) > 10 THEN 'Degraded'
#         ELSE 'Healthy'
#       END;
#   "
# }

# admin_login() {
#   read -p "Enter admin username: " user
#   read -sp "Enter admin password: " pass
#   echo ""
#   if [[ "$user" == "$ADMIN_USER" && "$pass" == "$ADMIN_PASS" ]]; then
#     echo "✅ Admin login successful."
#     admin_dashboard
#   else
#     echo "❌ Invalid admin credentials."
#   fi
# }

# while true; do
#   main_menu
#   case $choice in
#     1) create_user ;;
#     2) view_users ;;
#     3) make_transaction ;;
#     4) admin_login ;;
#     5) echo "👋 Exiting..." && break ;;
#     *) echo "❌ Invalid choice." ;;
#   esac
# done
