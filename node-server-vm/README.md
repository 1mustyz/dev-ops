# node-server-vm

A simple Node.js REST API with user authentication, built with **Express**, **Sequelize ORM**, and **MySQL**. Created for DevOps practice (containerisation, deployment, CI/CD, etc.).

## Features

- User registration with hashed passwords (bcrypt)
- Login with JWT token generation
- Protected route to retrieve the logged-in user's profile

## Tech Stack

- **Runtime**: Node.js
- **Framework**: Express
- **ORM**: Sequelize
- **Database**: MySQL
- **Auth**: JSON Web Tokens (JWT) + bcryptjs

## Project Structure

```
src/
├── app.js              # Entry point
├── config/
│   └── database.js     # Sequelize connection
├── models/
│   └── User.js         # User model
├── middleware/
│   └── auth.js         # JWT auth middleware
└── routes/
    └── auth.js         # Auth endpoints
```

## Setup

### Prerequisites

- Node.js (v18+)
- MySQL server running locally or remotely

### 1. Clone and install dependencies

```bash
git clone <your-repo-url>
cd node-server-vm
npm install
```

### 2. Configure environment variables

Copy the example file and fill in your values:

```bash
cp .env.example .env
```

| Variable         | Description                          | Default     |
| ---------------- | ------------------------------------ | ----------- |
| `PORT`           | Port the server listens on           | `8080`      |
| `DB_HOST`        | MySQL host                           | `localhost` |
| `DB_PORT`        | MySQL port                           | `3306`      |
| `DB_NAME`        | Database name                        | `nodeapp`   |
| `DB_USER`        | MySQL user                           | —           |
| `DB_PASSWORD`    | MySQL password (leave blank if none) | —           |
| `JWT_SECRET`     | Secret key for signing JWTs          | —           |
| `JWT_EXPIRES_IN` | Token expiry duration                | `1d`        |

### 3. Create the database

```sql
CREATE DATABASE nodeapp;
```

Sequelize will automatically create the `users` table on first run.

### 4. Start the server

```bash
# Production
npm start

# Development (auto-reload with nodemon)
npm run dev
```

## API Endpoints

### Register

```
POST /api/auth/register
Content-Type: application/json

{
  "username": "john",
  "email": "john@example.com",
  "password": "secret123"
}
```

### Login

```
POST /api/auth/login
Content-Type: application/json

{
  "email": "john@example.com",
  "password": "secret123"
}
```

Returns a JWT token:

```json
{
  "message": "Login successful",
  "token": "<jwt>"
}
```

### Get Logged-in User

```
GET /api/auth/me
Authorization: Bearer <token>
```

Returns the current user's profile (id, username, email, createdAt).
