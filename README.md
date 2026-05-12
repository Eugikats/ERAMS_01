# ERAMS — Emergency Response and Ambulance Management System

![PHP](https://img.shields.io/badge/PHP-8.2-777BB4?style=flat-square&logo=php&logoColor=white)
![Laravel](https://img.shields.io/badge/Laravel-11-FF2D20?style=flat-square&logo=laravel&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat-square&logo=mysql&logoColor=white)
![Android](https://img.shields.io/badge/Android-Driver%20App-3DDC84?style=flat-square&logo=android&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Status](https://img.shields.io/badge/Status-In%20Development-yellow?style=flat-square)

> **Final Year Project — Bachelor of Information Technology and Computing**  
> Makerere University | Uganda | Academic Year 2025–2026

---

## Project Description

ERAMS (Emergency Response and Ambulance Management System) is a web and mobile-based platform engineered to digitise and accelerate emergency medical response across selected hospitals in Uganda — one public (government) facility and one private facility. The system tackles well-documented real-world problems — manual phone-based dispatch, absent real-time GPS tracking, poor inter-agency coordination, and paper-based incident records — by delivering role-based access control (RBAC), an automated nearest-ambulance dispatch algorithm, live GPS tracking, digitalised incident logging, hospital arrival notifications, analytics dashboards with DHIS2 export capability, and a full digital audit trail; all through a responsive web frontend for Dispatchers, Hospital Staff, and Administrators, and an offline-tolerant Android application for Ambulance Drivers.

---

## System Architecture

ERAMS follows a **three-tier client-server architecture**:

| Tier | Layer | Technology |
|------|-------|------------|
| **Tier 1** | **Presentation Layer** — Responsive web frontend for Dispatchers, Hospital Staff, and Administrators; Android mobile application for Ambulance Drivers. | HTML5 / CSS3 / JavaScript · Android (Java) |
| **Tier 2** | **Application Layer** — PHP 8.2 RESTful API backend built with Laravel 11, handling business logic, dispatch algorithm, GPS ingestion, RBAC enforcement, and optional DHIS2 export. | Laravel 11 · PHP 8.2 · Sanctum |
| **Tier 3** | **Data Layer** — MySQL 8 relational database storing incidents, users, ambulances, GPS pings, and audit logs. | MySQL 8 · Laravel Eloquent ORM |

---

## Prerequisites

Ensure the following are installed on your development machine before proceeding:

| Requirement | Minimum Version | Download |
|---|---|---|
| PHP | 8.2 | https://www.php.net/downloads |
| Composer | 2.x | https://getcomposer.org |
| Node.js (+ npm) | 18 LTS | https://nodejs.org |
| MySQL Server | 8.0 | https://dev.mysql.com/downloads |
| Android Studio | Hedgehog (2023.1.1) + | https://developer.android.com/studio |
| Git | 2.x | https://git-scm.com |

> **Optional:** [DHIS2 sandbox credentials](https://play.dhis2.org) if you intend to test the DHIS2 export feature.



### Local Setup Instructions

### 1 — Clone the Repository

bash
git clone https://github.com/forva2025/ERAMS_01.git
cd eram

---

### 2 — Backend Setup (Laravel 11)

```bash
# Navigate to the backend directory
cd backend

# Install PHP dependencies via Composer
composer install

# Copy the environment file and open it for editing
cp .env.example .env

# Generate the application key
php artisan key:generate
```

**Edit `backend/.env`** and set your local values:

```dotenv
APP_NAME=ERAMS
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost:8000

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=erams
DB_USERNAME=root
DB_PASSWORD=your_password

DHIS2_BASE_URL=https://play.dhis2.org/40/api
DHIS2_USERNAME=admin
DHIS2_PASSWORD=district
```

```bash
# Create the MySQL database (run in MySQL CLI or GUI)
# CREATE DATABASE erams CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Run database migrations
php artisan migrate

# (Optional) Seed with demo data
php artisan db:seed

# Start the development server
php artisan serve
# → API available at http://localhost:8000/api
```

---

### 3 — Frontend Setup (Web UI)

The web frontend is plain HTML5 / CSS3 / JavaScript — no build step required.

```bash
# Navigate to the frontend directory
cd ../frontend

# Open directly in a browser
start index.html          # Windows
# OR serve via a local server for proper AJAX support:
npx -y serve .
# → UI available at http://localhost:3000
```

> **API base URL:** Update `frontend/assets/js/api.js` → `BASE_URL` constant to point to `http://localhost:8000/api`.

---

### 4 — Mobile App Setup (Android Driver App)

```bash
# Navigate to the mobile directory
cd ../mobile
```

1. Open **Android Studio** → **File → Open** → select the `mobile/` directory.
2. Wait for Gradle sync to complete.
3. Open `mobile/app/src/main/java/com/erams/driver/ApiClient.java` and update `BASE_URL` to your **backend IP** (use your LAN IP, not `localhost`, so the emulator/device can reach the server).
4. Run on an **emulator** (API 26+) or physical device via **Run → Run 'app'**.

---

## Running Tests

### Backend (PHPUnit)

```bash
cd backend

# Run all tests
php artisan test

# Run only unit tests
php artisan test --testsuite=Unit

# Run only feature tests
php artisan test --testsuite=Feature

# Run with coverage report (requires Xdebug or PCOV)
php artisan test --coverage
```

### Frontend (Manual / Browser DevTools)

Open any `.html` view in a browser with DevTools open. Network requests and console errors surface in the **Network** and **Console** tabs respectively.

### System & Integration Tests

See [`docs/Test_Plan.md`](docs/Test_Plan.md) for the full test matrix covering functional, integration, performance, and UAT test cases.

```bash
# Convenience aliases defined in tests/
tests/unit/          ← Unit-level stubs
tests/integration/   ← API integration scenarios
tests/system/        ← End-to-end system flows
tests/validation/    ← UAT acceptance checklists
```

---

## API Endpoint Reference

> **Base URL:** `http://localhost:8000/api`  
> **Authentication:** Laravel Sanctum (Bearer token). Obtain a token via `POST /auth/login`.

| Method | Endpoint | Auth | Role(s) | Description |
|--------|----------|------|---------|-------------|
| `POST` | `/auth/login` | ✗ | Public | Authenticate and receive Bearer token |
| `POST` | `/auth/logout` | ✔ | All | Invalidate current session token |
| `GET` | `/auth/me` | ✔ | All | Return authenticated user profile |
| `POST` | `/incidents` | ✔ | Dispatcher | Log a new emergency incident |
| `GET` | `/incidents` | ✔ | Dispatcher, Admin | List all incidents (paginated) |
| `GET` | `/incidents/{id}` | ✔ | Dispatcher, Admin | Get a single incident detail |
| `PATCH` | `/incidents/{id}/status` | ✔ | Dispatcher | Update incident status |
| `POST` | `/dispatch` | ✔ | Dispatcher | Trigger nearest-ambulance dispatch algorithm |
| `GET` | `/dispatch/{id}` | ✔ | Dispatcher, Admin | Get dispatch assignment detail |
| `GET` | `/ambulances` | ✔ | Dispatcher, Admin | List all ambulances and current status |
| `POST` | `/ambulances` | ✔ | Admin | Register a new ambulance |
| `PATCH` | `/ambulances/{id}` | ✔ | Admin | Update ambulance record |
| `DELETE` | `/ambulances/{id}` | ✔ | Admin | Remove an ambulance |
| `POST` | `/gps/ping` | ✔ | Driver | Submit a GPS location ping |
| `GET` | `/gps/{ambulanceId}/latest` | ✔ | Dispatcher | Retrieve latest GPS position |
| `GET` | `/gps/{ambulanceId}/history` | ✔ | Admin | Retrieve full GPS ping history |
| `GET` | `/notifications` | ✔ | Hospital, Admin | List notifications for the authenticated user |
| `POST` | `/notifications/mark-read` | ✔ | Hospital | Mark notification(s) as read |
| `GET` | `/reports/summary` | ✔ | Admin | Response-time and dispatch summary report |
| `GET` | `/reports/incidents` | ✔ | Admin | Detailed incident report (filterable) |
| `GET` | `/dhis2/export` | ✔ | Admin | Export aggregated data to DHIS2 |
| `GET` | `/users` | ✔ | Admin | List all system users |
| `POST` | `/users` | ✔ | Admin | Create a new user account |
| `PATCH` | `/users/{id}` | ✔ | Admin | Update user details or role |
| `DELETE` | `/users/{id}` | ✔ | Admin | Deactivate a user account |

> Full request/response schemas, validation rules, and error codes are documented in [`docs/API_Documentation.md`](docs/API_Documentation.md).

---

## Project Structure

```
ERAMS/
├── docs/                   ← Design artefacts, specs, test plan, user manual
│   └── diagrams/           ← ERD, DFD, UML diagrams
├── backend/                ← Laravel 11 PHP RESTful API
│   ├── app/Http/           ← Controllers, Middleware, Form Requests
│   ├── app/Models/         ← Eloquent ORM models
│   ├── app/Services/       ← Business logic services
│   ├── app/Events/         ← Laravel event classes (WebSocket broadcasts)
│   ├── database/           ← Migrations and seeders
│   └── routes/api.php      ← All API route definitions
├── frontend/               ← Web UI (HTML5 / CSS3 / JavaScript)
│   ├── assets/             ← CSS, JS, and image assets
│   └── views/              ← auth, dispatcher, hospital, and admin pages
├── mobile/                 ← Android Driver Application (Java)
│   └── app/src/main/java/com/erams/driver/
└── tests/                  ← Test suites (unit, integration, system, validation)
```

---

## Team

| Name | Student Number | Primary Role |
|---|---|---|
| Ashaba Ritah | — | 
| Ochiria Elias Onyait | |
| Katusiime Eugene | — | |
| Ashaka Joseph | — |  |

---

## Supervisor Acknowledgement

This project is submitted in partial fulfilment of the requirements for the award of the **Bachelor of Information Technology and Computing** at **Kyambogo University, Uganda**.

We sincerely thank our project supervisor Ms Shallom for her continued guidance, valuable feedback, and support throughout the design and development of ERAMS. Their technical insight and encouragement have been instrumental in shaping the direction and quality of this work.

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for full details.

© 2025–2026 ERAMS Team — Kyambogo University
