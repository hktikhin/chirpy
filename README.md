# Chirpy

A robust micro-blogging REST API backend built with Go and PostgreSQL. It powers a Twitter-like platform with secure authentication, chirp management, static file serving, and premium "Chirpy Red" upgrades.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)]()

## Overview

Chirpy is a high-performance RESTful API written in **Go** using **PostgreSQL** as the database. It implements industry-standard security practices, including **Argon2id** password hashing, short-lived **JWT** access tokens, and database-backed **Refresh Token** rotation with revocation.

The API also serves static frontend files with visit tracking and includes profanity filtering for chirps.

## Features

- **Secure Authentication**:
  - Argon2id password hashing
  - Short-lived JWT Access Tokens (1 hour)
  - Long-lived Refresh Tokens (60 days) stored in PostgreSQL with revocation support
- **Static File Serving**: Serves assets from the root directory with an atomic hit counter middleware
- **Chirps Management**: Create (with profanity cleaning), read (filtered & sorted), and delete own chirps (max 140 characters)
- **Dynamic Querying**: Filter by `author_id` and sort by creation time (ASC/DESC)
- **Chirpy Red**: Secure webhook for upgrading users to premium via Polka
- **Type-Safe Database Layer**: Generated with **SQLC**

## Requirements

- **Go 1.20+**
- **PostgreSQL 12+**
- **Goose** (for migrations)
- **SQLC** (for type-safe queries)

## Quick Start

### 1. Install Tools

```bash
go install github.com/pressly/goose/v3/cmd/goose@latest
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
```

### 2. Database Setup

```bash
psql -U postgres -c "CREATE DATABASE chirpy;"
cd sql/schema/
goose postgres "postgres://postgres:postgres@localhost:5432/chirpy?sslmode=disable" up
```

### 3. Configuration

Create a `.env` file in the project root:

```env
DB_URL=postgres://postgres:postgres@localhost:5432/chirpy?sslmode=disable
PLATFORM=dev
TOKEN_SECRET=your_super_secret_jwt_key_here_change_in_production
POLKA_KEY=f271c81ff7084ee5b99a5091b42d486e
```

### 4. Run the Server

```bash
go run .
```

The server listens on `http://localhost:8080`.

## API Reference

### 📂 File Serving & Admin

| Method | Endpoint              | Description                                              | Auth          |
|--------|-----------------------|----------------------------------------------------------|---------------|
| GET    | `/app/*`              | Serve static files (with hit counter)                    | None          |
| GET    | `/api/healthz`        | Health check                                             | None          |
| GET    | `/admin/metrics`      | View total site visits (HTML)                            | None          |
| POST   | `/admin/reset`        | **Dev only**: Reset counter and delete all users         | None          |

### 🔐 Authentication

| Method | Endpoint           | Description                                              | Auth Required              |
|--------|--------------------|----------------------------------------------------------|----------------------------|
| POST   | `/api/users`       | Register new user                                        | None                       |
| PUT    | `/api/users`       | Update email and/or password                             | JWT Access Token           |
| POST   | `/api/login`       | Login → returns Access Token + Refresh Token             | None                       |
| POST   | `/api/refresh`     | Exchange Refresh Token for new Access Token              | Refresh Token              |
| POST   | `/api/revoke`      | Revoke Refresh Token (logout)                            | Refresh Token              |

### 🐦 Chirps

| Method | Endpoint                | Description                                              | Auth Required         |
|--------|-------------------------|----------------------------------------------------------|-----------------------|
| POST   | `/api/chirps`           | Create chirp (max 140 chars, profanity filtered)         | JWT Access Token      |
| GET    | `/api/chirps`           | List chirps (`?author_id=` & `?sort=desc`)               | None                  |
| GET    | `/api/chirps/{chirpID}` | Get single chirp by ID                                   | None                  |
| DELETE | `/api/chirps/{chirpID}` | Delete your own chirp                                    | JWT Access Token      |

### ⚡ Webhooks

| Method | Endpoint                   | Description                           | Auth      |
|--------|----------------------------|---------------------------------------|-----------|
| POST   | `/api/polka/webhooks`      | Upgrade user to Chirpy Red            | ApiKey    |

## Architecture & Implementation Details

- **Routing**: Standard library `http.ServeMux` with path values for dynamic routes (e.g. `{chirpID}`).
- **Metrics Middleware**: Uses `sync/atomic.Int32` for lock-free increment of file server hits.
- **Authentication**:
  - JWT tokens generated and validated via the `internal/auth` package.
  - Refresh Tokens stored in the `refresh_tokens` table with `expires_at` (60 days) and `revoked_at` timestamp.
- **Refresh Token Flow**:
  - On login: A new Refresh Token is created with `expires_at = now + 60 days`.
  - On `/api/refresh`: Validates the token exists, is not revoked (`revoked_at IS NULL`), and `expires_at > now`. Issues a new Access Token.
  - On `/api/revoke`: Marks the token as revoked.
- **Chirps**:
  - Body is cleaned by replacing profanity words (`kerfuffle`, `sharbert`, `fornax`) with `****`.
  - Listing supports author filtering and in-memory sorting with `sort.Slice`.
  - Deletion checks ownership before allowing the operation.
- **Database**: Type-safe queries generated by SQLC. Uses `github.com/lib/pq` driver.
- **Other**:
  - Environment-based behavior (`PLATFORM=dev` enables reset).
  - Consistent JSON responses and error handling.

## Project Structure Highlights

- `internal/auth` — JWT, password hashing, token helpers
- `internal/database` — SQLC-generated queries
- `sql/schema/` — Database migrations (Goose)
- `.env` — Configuration

## Acknowledgments

Built following the **Boot.dev** "Learn Web Servers in Go" course, with a complete Refresh Token implementation, metrics middleware, and profanity filtering.

## License

MIT License