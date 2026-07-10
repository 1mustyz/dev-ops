# DevOps Lab — Multi-VM Full-Stack App

A hands-on DevOps practice project using **Vagrant** + **libvirt** to spin up a four-machine private network running a full-stack web application. The goal is to practice infrastructure provisioning, service configuration, and automation with shell scripts.

---

## Architecture

```
Browser
   │
   ▼  :8080 (forwarded)
┌──────────────────────┐
│  nginx (192.168.56.11)│  ← reverse proxy
└──────────┬───────────┘
           │ proxies to :3000
           ▼
┌──────────────────────┐
│ react-app            │  ← React 19 SPA
│ (192.168.56.13:3000) │
└──────────────────────┘
           │ API calls
           ▼
┌──────────────────────┐     ┌──────────────────────┐
│ node-app             │────▶│  db                  │
│ (192.168.56.12:8080) │     │ (192.168.56.10:3306) │
│ Express REST API     │     │ MariaDB              │
└──────────────────────┘     └──────────────────────┘
```

| VM          | Hostname  | IP            | Role                  | RAM    |
| ----------- | --------- | ------------- | --------------------- | ------ |
| `db`        | db        | 192.168.56.10 | MariaDB database      | 1 GB   |
| `nginx`     | nginx     | 192.168.56.11 | Nginx reverse proxy   | 512 MB |
| `node-app`  | node-app  | 192.168.56.12 | Node.js / Express API | 1 GB   |
| `react-app` | react-app | 192.168.56.13 | React front-end       | 2 GB   |

All VMs run **CentOS 10 Stream** (`alvistack/centos-10-stream`) via the **libvirt** provider.  
Host port **8080** is forwarded to the nginx VM's port **80**.

---

## Project Structure

```
my-first-vm/
├── Vagrantfile             # Defines all 4 VMs
├── msqldb.sh               # Provisions the db VM (MariaDB)
├── nginx.sh                # Provisions the nginx VM (reverse proxy)
├── node-server-vm/         # Node.js Express API source
│   ├── src/
│   │   ├── app.js
│   │   ├── config/database.js
│   │   ├── middleware/auth.js
│   │   ├── models/User.js
│   │   └── routes/auth.js
│   ├── .env.example
│   └── package.json
└── react-vm/               # React front-end source
    ├── src/
    │   ├── App.js
    │   └── pages/
    │       ├── Login.js
    │       ├── Register.js
    │       └── Dashboard.js
    ├── build/              # Production build (served by react-app VM)
    ├── .env.example
    └── package.json
```

---

## Prerequisites

- [Vagrant](https://developer.hashicorp.com/vagrant/downloads) ≥ 2.3
- [libvirt](https://libvirt.org/) + [vagrant-libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt) plugin
- 6+ GB of free RAM

Install the libvirt plugin if you haven't already:

```bash
vagrant plugin install vagrant-libvirt
```

---

## Quick Start

### 1. Boot all VMs

```bash
vagrant up
```

Or boot them individually:

```bash
vagrant up db
vagrant up node-app
vagrant up react-app
vagrant up nginx
```

### 2. Provision the database VM

SSH into the `db` machine and run the provisioning script:

```bash
vagrant ssh db
sudo bash /vagrant/msqldb.sh
```

This will:

- Install MariaDB and configure it to listen on all interfaces (`0.0.0.0`)
- Create the `nodeuser` application user with access from `192.168.56.12`
- Grant all privileges on the `nodeapp` database

### 3. Set up the Node.js API

```bash
vagrant ssh node-app
cd /vagrant/node-server-vm
cp .env.example .env        # edit values if needed
npm install
npm start
```

The API listens on port **8080** (or the value of `PORT` in `.env`).

### 4. Set up the React front-end

```bash
vagrant ssh react-app
cd /vagrant/react-vm
cp .env.example .env        # set REACT_APP_API_URL
npm install
npm start                   # development server on :3000
# or: npx serve -s build    # serve the production build
```

### 5. Provision the nginx reverse proxy

```bash
vagrant ssh nginx
sudo bash /vagrant/nginx.sh
```

Nginx will proxy all traffic on port 80 → `192.168.56.13:3000` (React app).  
Access the app from your host at: **http://localhost:8080**

---

## Application Features

The app provides a simple authentication flow:

| Endpoint             | Method | Description                |
| -------------------- | ------ | -------------------------- |
| `/`                  | GET    | Health check               |
| `/api/auth/register` | POST   | Register a new user        |
| `/api/auth/login`    | POST   | Login, returns JWT         |
| `/api/auth/me`       | GET    | Get profile (JWT required) |

Passwords are hashed with **bcryptjs**. Sessions use **JWT** (configurable expiry via `JWT_EXPIRES_IN`).

---

## Environment Variables

### `node-server-vm/.env`

| Variable         | Default      | Description                 |
| ---------------- | ------------ | --------------------------- |
| `PORT`           | `8080`       | API server port             |
| `DB_HOST`        | `localhost`  | MariaDB host                |
| `DB_PORT`        | `3306`       | MariaDB port                |
| `DB_NAME`        | `nodeapp`    | Database name               |
| `DB_USER`        | `nodeuser`   | Database user               |
| `DB_PASSWORD`    | `mypassword` | Database password           |
| `JWT_SECRET`     | —            | Secret key for signing JWTs |
| `JWT_EXPIRES_IN` | `1d`         | JWT expiry duration         |

### `react-vm/.env`

| Variable            | Default                          | Description          |
| ------------------- | -------------------------------- | -------------------- |
| `REACT_APP_API_URL` | `http://localhost:8080/api/auth` | Backend API base URL |

---

## Useful Vagrant Commands

```bash
vagrant status              # check VM states
vagrant ssh <vm-name>       # SSH into a specific VM
vagrant halt                # shut down all VMs
vagrant halt <vm-name>      # shut down one VM
vagrant destroy -f          # delete all VMs
vagrant reload <vm-name>    # restart a VM
```

---

## Tech Stack

| Layer     | Technology                          |
| --------- | ----------------------------------- |
| Infra     | Vagrant + libvirt, CentOS 10 Stream |
| Proxy     | Nginx                               |
| Front-end | React 19, React Router v7           |
| Back-end  | Node.js, Express 4, Sequelize 6     |
| Database  | MariaDB (MySQL-compatible)          |
| Auth      | JWT (`jsonwebtoken`), bcryptjs      |
