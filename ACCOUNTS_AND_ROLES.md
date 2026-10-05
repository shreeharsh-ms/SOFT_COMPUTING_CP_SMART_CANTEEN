# 🔐 Smart Campus Canteen — User Accounts & Role Matrix

This document lists all active demo and seeded user accounts in the PostgreSQL database, their authentication credentials (email & 10-digit mobile number), operational roles, and platform permissions.

---

## 📋 Credentials Summary Table

| Full Name | Role | Email / Username | Mobile Number | Password | Landing Screen | Assigned Canteen |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Campus Administrator** | `ADMIN` | `admin@campus.edu` | `9876543210` | `Admin@Pass2026!` | `/admin` | Campus-wide (All) |
| **Chef Ramesh** | `KITCHEN` | `ramesh.c1@campus.edu` | `9876543211` | `Chef@Ramesh26` | `/kitchen` | Canteen #1 (North Campus) |
| **Aarav Sharma** | `CUSTOMER` | `aarav.student@campus.edu` | `9876543213` | `Student@Aarav26` | `/home` | All Canteens |
| **Shree** | `CUSTOMER` | `shree@gmail.com` | `1234567890` | `password123` | `/home` | All Canteens |

> 💡 **Tip:** You can log in using **either** your **Email Address** OR your **10-Digit Mobile Number** in the username field!

---

## 👥 Role Descriptions & Permissions Breakdown

### 1. 🛡️ Campus Administrator (`ADMIN`)
- **Login Credentials:**
  - Email: `admin@campus.edu`
  - Mobile: `9876543210`
  - Password: `Admin@Pass2026!`
- **Primary Landing Route:** `/admin` (Executive Dashboard)
- **Key Capabilities & Screen Access:**
  - **Executive Analytics:** Real-time revenue metrics, active orders counter, total student counts, and canteen fleet KPIs.
  - **Menu Management (`/admin/menu`):** Create, update, toggle availability, and set pricing / discount rates for any menu item across outlets.
  - **Soft Computing Resource Optimizer:** View real-time Genetic Algorithm (GA) kitchen load balancing advisory for rush-hour staffing and surge pricing recommendations.
  - **Physical Cash Counter Top-Up:** Instant counter top-up of student digital wallets when cash is deposited at reception.
  - **Fleet-Wide Canteen Access:** View and switch between North Campus Food Court and South Terrace Cafe at any time.

---

### 2. 👨‍🍳 Kitchen Staff / Chef (`KITCHEN`)
- **Login Credentials:**
  - Email: `ramesh.c1@campus.edu`
  - Mobile: `9876543211`
  - Password: `Chef@Ramesh26`
- **Primary Landing Route:** `/kitchen` (Kitchen Monitor Station)
- **Assigned Outpost:** Canteen #1 (North Campus Food Court)
- **Key Capabilities & Screen Access:**
  - **Live Order Stream:** Receives incoming orders in real time via first-frame authenticated WebSockets.
  - **Soft Computing Particle Swarm Optimization (PSO):** Active orders are ordered in sequence to minimize average waiting time across shared kitchen burners.
  - **Order Lifecycle Controls:**
    - **`Start Prep`**: Transitions status from `PLACED` $\rightarrow$ `PREPARING` (notifies student live).
    - **`Mark Ready`**: Transitions status from `PREPARING` $\rightarrow$ `READY` (triggers pickup counter notification).
    - **`Handover`**: Transitions status from `READY` $\rightarrow$ `COMPLETED` upon QR/Token presentation.
    - **`Reject & Auto-Refund`**: Instant order rejection with automated PostgreSQL-level transaction refund back to the customer's wallet.
  - **Station Log Out:** One-click session sign out via the top app bar.

---

### 3. 🎓 Student / Customer (`CUSTOMER`)
- **Demo Account #1:**
  - Name: **Aarav Sharma**
  - Email: `aarav.student@campus.edu` | Mobile: `9876543213`
  - Password: `Student@Aarav26`
  - Pre-funded Balance: `150.00 Tokens`
- **Demo Account #2:**
  - Name: **Shree**
  - Email: `shree@gmail.com` | Mobile: `1234567890`
  - Password: `password123`
- **Primary Landing Route:** `/home` (Main Shell with Bottom Navigation)
- **Key Capabilities & Screen Access:**
  - **Canteen Discovery:** Browse all campus canteens with live fuzzy crowd density indicators (`QUIET`, `MODERATE`, `PEAK`), queue lengths, and wait-time estimations.
  - **Menu Browsing & Cart:** Real-time stock counters, cross-canteen ordering constraints, and item quantity selection.
  - **Digital Wallet (`/wallet`):** Campus token ledger, live balance display, and comprehensive transaction audit history.
  - **Live Order Tracker (`/order-detail`):** Digital pickup token (e.g. `CC42`), scannable QR code, and real-time status tracker via WebSockets.
  - **Statutory GST Tax Invoice:** Formal Indian CGST/SGST compliant tax invoice with seller GSTIN, SAC codes, and taxable value breakdown.
  - **Instant Cancellation:** Self-service order cancellation while in `PLACED` or `CONFIRMED` status with instant wallet refund.
  - **Profile Management:** View registered profile details, balance, and account sign out.

---

## 🌐 Quick Access URLs

| Application / Service | URL | Notes |
| :--- | :--- | :--- |
| **Flutter Web Application** | [http://localhost:3000](http://localhost:3000) | Full responsive customer, kitchen & admin interface |
| **FastAPI Backend Server** | [http://localhost:8000](http://localhost:8000) | High-performance Async REST & WebSocket server |
| **Interactive Swagger Docs** | [http://localhost:8000/docs](http://localhost:8000/docs) | Live API testing & OpenAPI documentation |
| **PostgreSQL Database** | `localhost:5432` (`smart_canteen_db`) | All 12 entity models and ledger relations |
