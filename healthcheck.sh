#!/bin/bash

DB_USER="root"
DB_PASS="root_password"
DB_NAME="fraud_detection"
DB_PORT="3307"
LOG_FILE="logs/fraud_system.log"

mkdir -p logs
echo "🕒 Health Check at $(date)" >> "$LOG_FILE"

# Rule 1: High-value transactions
echo "🚨 High-value transactions (> 10000):" >> "$LOG_FILE"
mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e "
  SELECT id, user_id, amount, timestamp FROM transactions WHERE amount > 10000;
" >> "$LOG_FILE" 2>>"$LOG_FILE"

# Rule 2: Users with > 3 transactions in last 1 min
echo "🚨 Rapid-fire transactions (more than 3 in 1 min):" >> "$LOG_FILE"
mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS -P$DB_PORT -D$DB_NAME -e "
  SELECT user_id, COUNT(*) AS tx_count
  FROM transactions
  WHERE timestamp >= NOW() - INTERVAL 2 MINUTE
  GROUP BY user_id
  HAVING tx_count > 3;
" >> "$LOG_FILE" 2>>"$LOG_FILE"

echo "✅ Health Check completed at $(date)" >> "$LOG_FILE"
echo "-----------------------------" >> "$LOG_FILE"



# #!/bin/bash

# DB_USER="root"
# DB_PASS="root_password"
# DB_NAME="fraud_detection"
# DB_PORT="3307"

# LOG_FILE="logs/health_log.txt"
# log() {
#   echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
# }



# echo "📡 Running Scheduled Health Check - $(date)"

# # Health check status (Dummy - mark healthy if response time < 0.5s)
# START=$(date +%s.%N)
# mysql -h127.0.0.1 -P$DB_PORT -u$DB_USER -p$DB_PASS -D$DB_NAME -e "SELECT 1;"
# END=$(date +%s.%N)
# RESP_TIME=$(echo "$END - $START" | bc)
# STATUS="Healthy"
# if (( $(echo "$RESP_TIME > 0.8" | bc -l) )); then STATUS="Degraded"; fi

# # Insert healthcheck
# mysql -h127.0.0.1 -P$DB_PORT -u$DB_USER -p$DB_PASS -D$DB_NAME -e "
#   INSERT INTO health_checks (status, response_time)
#   VALUES ('$STATUS', $RESP_TIME);
# "

# # Run fraud detection logic (same as CLI)
# mysql -h127.0.0.1 -P$DB_PORT -u$DB_USER -p$DB_PASS -D$DB_NAME -e "
#   UPDATE transactions
#   SET is_fraud = TRUE
#   WHERE amount > 10000
#   AND is_fraud = FALSE;
# "

# mysql -h127.0.0.1 -P$DB_PORT -u$DB_USER -p$DB_PASS -D$DB_NAME -e "
#   INSERT INTO fraud_alerts (transaction_id, reason)
#   SELECT t.id, 'High value'
#   FROM transactions t
#   WHERE t.amount > 10000
#   AND NOT EXISTS (
#     SELECT 1 FROM fraud_alerts f WHERE f.transaction_id = t.id
#   );
# "

# # Metrics log
# USER_COUNT=$(mysql -sse "SELECT COUNT(*) FROM users;" -h127.0.0.1 -P$DB_PORT -u$DB_USER -p$DB_PASS -D$DB_NAME)
# TX_COUNT=$(mysql -sse "SELECT COUNT(*) FROM transactions;" -h127.0.0.1 -P$DB_PORT -u$DB_USER -p$DB_PASS -D$DB_NAME)
# FRAUD_COUNT=$(mysql -sse "SELECT COUNT(*) FROM transactions WHERE is_fraud = TRUE;" -h127.0.0.1 -P$DB_PORT -u$DB_USER -p$DB_PASS -D$DB_NAME)

# mysql -h127.0.0.1 -P$DB_PORT -u$DB_USER -p$DB_PASS -D$DB_NAME -e "
#   INSERT INTO metrics (metric_name, value)
#   VALUES 
#     ('user_count', $USER_COUNT),
#     ('transaction_count', $TX_COUNT),
#     ('fraud_count', $FRAUD_COUNT);
# "
# echo "✅ Health check complete | Resp time: ${RESP_TIME}s | Users: $USER_COUNT | Tx: $TX_COUNT | Fraud: $FRAUD_COUNT"
