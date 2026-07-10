# React VM App

A minimal React application built for **DevOps / CI-CD practice**.

The app intentionally has very little business logic so the focus stays on the pipeline, containerisation, and deployment rather than the application itself.

---

## Purpose

| Goal | Description |
|------|-------------|
| DevOps practice | Provide a real deployable artefact for pipeline experiments |
| CI/CD | Lint → build → Docker image → push → deploy |
| Containerisation | Easy to Dockerise with a static Nginx image |
| Infrastructure | Suitable for Kubernetes, Docker Compose, or VM deployments |

---

## Features

| Route | Description |
|-------|-------------|
| `/register` | Create a new account |
| `/login` | Sign in and receive a JWT |
| `/dashboard` | View the currently logged-in user's profile |

---

## API Contract

The app talks to a backend running on `http://localhost:8080`.

### Register
```
POST /api/auth/register
Content-Type: application/json

{ "username": "...", "email": "...", "password": "..." }
```
Response:
```json
{
  "message": "User registered successfully",
  "user": { "id": 4, "username": "musty2", "email": "onemusty.zw@gmail.com" }
}
```

### Login
```
POST /api/auth/login
Content-Type: application/json

{ "email": "...", "password": "..." }
```
Response:
```json
{
  "message": "Login successful",
  "token": "<jwt>"
}
```
The JWT is stored in `localStorage` and sent as `Authorization: Bearer <token>` on protected requests.

### Get current user
```
GET /api/auth/me
Authorization: Bearer <token>
```
Response:
```json
{
  "user": {
    "id": 4,
    "username": "musty2",
    "email": "onemusty.zw@gmail.com",
    "createdAt": "2026-07-09T23:08:51.000Z"
  }
}
```

---

## Tech Stack

- **React 18** + **Vite 5** (fast dev server & optimised production build)
- **React Router v6** (client-side routing)
- CSS Modules (scoped styles, zero extra dependencies)

---

## Getting Started

```bash
# Install dependencies
npm install

# Start development server (http://localhost:3000)
npm run dev

# Production build  → dist/
npm run build

# Preview production build locally
npm run preview
```

---

## Docker (example)

```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

```bash
docker build -t react-vm:latest .
docker run -p 3000:80 react-vm:latest
```

---

## Project Structure

```
react-vm/
├── index.html
├── vite.config.js
├── package.json
├── src/
│   ├── main.jsx          # App entry point
│   ├── App.jsx           # Routes
│   ├── index.css         # Global reset
│   └── pages/
│       ├── Register.jsx
│       ├── Login.jsx
│       ├── Dashboard.jsx
│       ├── Auth.module.css
│       └── Dashboard.module.css
└── README.md
```
