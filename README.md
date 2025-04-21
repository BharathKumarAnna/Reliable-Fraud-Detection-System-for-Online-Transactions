# 💳 CLI-Based Fraud Detection System

A shell-scripted command-line application for secure UPI transactions, user management, and real-time fraud detection using MySQL and Docker. It includes OTP-based user authentication, admin controls, and transaction anomaly detection through automated health checks.

---

## 📦 Features

- 🔐 **User Authentication** with OTP verification and bcrypt-hashed passwords
- 💸 **UPI-Based Transactions** with balance tracking
- 🚨 **Fraud Detection Logic**:
  - High-value transaction alerts
  - Rapid transaction alerts
- 📊 **CLI Dashboard** for users and admins
- ♻️ **Health Monitoring** and system logging
- 🐳 **Dockerized** MySQL setup with preloaded schema

---

## 📁 Project Structure

```
.
├── clidashboard.sh          # Main CLI script (User + Admin interface)
├── healthcheck.sh           # Automated fraud rule checks
├── docker-compose.yml       # Docker environment setup
├── init_db.sql              # MySQL DB schema & table creation
├── requirements.txt         # Python packages (bcrypt, PyMySQL)
└── logs/                    # Health and fraud logs
```

---

## 🚀 Getting Started

### 1. Clone the Repo & Launch MySQL in Docker

```bash
git clone <your-repo-url>
cd project-folder
docker-compose up -d
```

### 2. Initialize Environment

Install required Python libraries:
```bash
pip install -r requirements.txt
```

### 3. Run the CLI Dashboard

```bash
chmod +x clidashboard.sh
./clidashboard.sh
```

### 4. Run Scheduled Health Checks (Optional)

```bash
chmod +x healthcheck.sh
./healthcheck.sh
```

---

## 🗃️ Database Schema Highlights

- `users`: name, phone, email, upi_id, balance, hashed password
- `transactions`: amount, timestamp, fraud flag
- `fraud_alerts`: transaction-based flags
- `metrics`, `health_checks`: system performance and anomaly data
- `user_otp`: for secure verification

---

## 🛡️ Fraud Rules Implemented

- 🚨 Transactions > ₹10,000
- 🚨 More than 3 transactions by a user in 2 minutes

Alerts are logged in `logs/fraud_system.log`.

---

## 👨‍💻 Admin Access

Admin credentials (default):
```
Username: admin
Password: secret123
```

(Admin module can be extended further.)

---

## 📌 Dependencies

- Bash
- Python 3
- MySQL 8 (via Docker)
- bcrypt, PyMySQL (Python)
- Docker + Docker Compose

---

## 📜 License

MIT License — feel free to use and modify with credits.

---

## ✨ Author

Developed with ❤️ by Bharath Kumar Anna 

---