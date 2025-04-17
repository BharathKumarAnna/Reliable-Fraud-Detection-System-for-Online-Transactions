# 💳 Reliable Fraud Detection System (v1.0)

A simple CLI-based fraud detection system using **Shell**, **MySQL**, and **Docker**. Designed for fast prototyping, offline simulations, and practicing full-stack CLI + DB systems.

---

## 🧰 Tech Stack
- **Shell Script (Bash)** — CLI dashboard
- **MySQL** — Database and rules
- **Docker** — MySQL containerization

---

## ⚙️ Features

### 🔸 CLI Menu
```
1. Create User
2. View Users
3. Make Transaction
4. Admin Login
5. Fraud Rules
6. View Dashboard Metrics
7. Exit
```

### 👤 User Module
- Add user with name and email.
- View all users with current balances.

### 💸 Transaction Module
- Add transactions for a user.
- Updates balance in real-time.

### 🔐 Admin Module
- Requires admin password (`admin123` by default).
- Runs fraud detection rules.

### 🚨 Fraud Rules
1. **Transactions > 10000** — Flagged as suspicious.
2. **More than 3 transactions in 1 minute** — Flagged.

Results stored in `fraud_alerts` and updated in `transactions` via `is_fraud = TRUE`.

### 📊 Metrics Dashboard
- Total users, transactions.
- Fraud count.
- HealthCheck status.

---

## 🐳 Docker Setup

### 🔸 Run MySQL via Docker
```bash
docker-compose up -d
```
- MySQL root user: `root`
- Password: `root_password`
- Port: `3307`

### 🔸 Initialize DB
```bash
docker exec -it fraud_detection_mysql mysql -uroot -proot_password < init_db.sql
```

---

## 🚀 Start CLI
```bash
chmod +x clidashboard.sh
./clidashboard.sh
```

---

## 📂 File Structure
```
.
├── clidashboard.sh       # Shell CLI dashboard
├── init_db.sql           # MySQL schema
├── docker-compose.yaml   # MySQL setup
└── README.md             # Project guide
```

---

## 🧪 Sample Users & Transactions
Use options 1 and 3 in the CLI to populate data. You may simulate fraud by sending:
- 4+ transactions in under 1 minute
- One transaction above 10000

---

## ✅ Done!
This is the **v1.0** of a CLI-based transaction fraud detection system.

For future versions:
- Add export-to-CSV
- Add logging & cron jobs
- Add Python web dashboard

> Created by Bharath Kumar | April 2025

# source venv/bin/activate