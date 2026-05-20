# 🌾 SAMS Market - Farmers Marketplace

![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![Python](https://img.shields.io/badge/Language-Python_3.12-3776AB?style=for-the-badge&logo=python&logoColor=white)
![SQLite](https://img.shields.io/badge/Database-SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)
![AWS](https://img.shields.io/badge/Hosted-AWS_EC2-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)

SAMS Market is a full-stack, direct-to-consumer e-commerce mobile application designed to bridge the gap between local farmers and buyers. By eliminating the middleman, farmers retain higher profit margins while buyers get access to fresh, affordable produce.

## 🚀 Features

### 👨‍🌾 Farmer Portal (Sellers)
* **Inventory Management:** Full CRUD operations for produce (Add, Update, Delete) with image uploads.
* **Order Processing:** Real-time dashboard to review, accept, or reject incoming buyer orders.
* **Automated Stock Deduction:** Accepting an order automatically updates global inventory.
* **Financial Analytics:** Live calculations of total listings, pending requests, and total revenue earned.

### 🛒 Buyer Portal (Consumers)
* **Dynamic Marketplace:** Filter, search, and browse fresh produce using a responsive Glassmorphism UI.
* **Secure Cart System:** Multi-item cart state management with real-time total calculations.
* **Order Tracking:** Monitor active and historical orders (Pending, Accepted, Delivered, Cancelled).

### 💬 Global Features
* **Role-Based Authentication:** Secure login routing users to their specific dashboard contexts.
* **Real-Time Messaging:** Integrated chat system allowing Buyers and Farmers to communicate regarding specific orders.
* **Local Caching:** Heavy utilization of `SharedPreferences` to cache profiles, produce, and orders for instant load times and offline resilience.

---

## 🛠️ System Architecture

* **Frontend:** Built with **Flutter (Dart)** for cross-platform mobile performance. Implements a highly polished UI with custom animations, shimmer loading states, and robust network error handling.
* **Backend:** Powered by **FastAPI (Python)**. Chosen for its extreme speed, asynchronous capabilities, and automatic OpenAPI documentation generation.
* **Database:** **SQLite** managed via **SQLAlchemy ORM** for relational data integrity between Users, Produce, Orders, and Messages.
* **Infrastructure:** Deployed live on an **AWS EC2 (Ubuntu)** instance using `Uvicorn`.

---

## 💻 Installation & Setup

### 1. Backend (FastAPI)
Navigate to the backend directory, set up your virtual environment, and run the server:
```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # On Windows use `venv\Scripts\activate`
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload