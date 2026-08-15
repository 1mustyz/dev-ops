# Full-Stack DevOps Learning Project

This project documents my hands-on journey from running a full-stack application inside virtual machines with **Vagrant** to containerizing it with **Docker**, orchestrating it with **Docker Compose**, deploying it to **AWS EC2**, publishing Docker images to **Amazon ECR**, and finally building a complete **CI/CD pipeline with GitHub Actions**.

The application consists of:

- **Frontend:** React (`react-vm`)
- **Backend:** Node.js (`node-server-vm`)
- **Database:** MySQL
- **Web server / reverse proxy:** Nginx
- **Container runtime:** Docker
- **Multi-container orchestration:** Docker Compose
- **Cloud compute:** AWS EC2
- **Container registry:** Amazon ECR
- **CI/CD:** GitHub Actions
- **AWS authentication:** GitHub OIDC + IAM
- **Remote deployment:** AWS Systems Manager (SSM)

---

## Learning Goals

The goal of this project was not only to deploy an application, but to understand how the major pieces of a DevOps workflow fit together.

I wanted to understand:

- Virtual machines and infrastructure with Vagrant
- Docker images and containers
- Docker networking
- Docker volumes
- Docker Compose
- Multi-stage Docker builds
- Nginx and reverse proxying
- Deploying containers to an AWS EC2 server
- Storing Docker images in Amazon ECR
- IAM roles and permissions
- GitHub Actions workflows
- CI vs CD
- GitHub OIDC authentication with AWS
- Versioning Docker images with Git commit SHAs
- Automated deployments using AWS Systems Manager

---

# Project Structure

The repository is organized as a monorepo containing both the frontend and backend applications.

```text
.
├── react-vm/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── package.json
│   └── src/
│
├── node-server-vm/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── compose.yaml
├── Vagrantfile
└── README.md
```

The two application services are built as separate Docker images even though they live in the same Git repository.

```text
Repository
├── react-vm       → frontend Docker image
└── node-server-vm → backend Docker image
```

MySQL uses the official MySQL image instead of a custom image.

---

# Application Architecture

The application currently runs on a single AWS EC2 instance.

```text
                    Internet
                       │
                       │ HTTP :80
                       ▼
              ┌─────────────────┐
              │    AWS EC2      │
              │                 │
              │  Docker Compose │
              │                 │
              │  React + Nginx  │
              │       │         │
              │       ▼         │
              │    Node.js      │
              │       │         │
              │       ▼         │
              │     MySQL       │
              │                 │
              └─────────────────┘
```

Only the frontend/Nginx container is exposed publicly.

Internally the services communicate through the Docker Compose network.

```text
Browser
   │
   │ port 80
   ▼
Nginx / React
   │
   │ backend:8080
   ▼
Node.js
   │
   │ mysql:3306
   ▼
MySQL
```

This means the backend and database do not need public ports.

---

# Stage 1 — Vagrant

The project originally started with **Vagrant**.

Vagrant was used to create reproducible virtual-machine environments for the application.

At this stage I learned the difference between:

```text
Host machine
     │
     ▼
Virtual Machine
     │
     ▼
Application
```

The frontend and backend directories still use their original names:

```text
react-vm
node-server-vm
```

Using Vagrant helped me understand:

- What a virtual machine is
- Host vs guest operating systems
- Provisioning a development environment
- Port forwarding
- Networking between the host and guest
- Reproducible infrastructure

The next step was learning how Docker solves a similar problem at the application-container level.

---

# Stage 2 — Dockerizing the Application

The application was then containerized with Docker.

Three services are involved:

```text
Frontend
Backend
MySQL
```

The frontend and backend use custom Dockerfiles.

MySQL uses:

```yaml
image: mysql:8.4
```

Docker automatically pulls this image from the image registry when it is not already available locally.

---

# Frontend Container

The React frontend uses a multi-stage Docker build.

Example:

```dockerfile
FROM node:20 AS build

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build

FROM nginx:alpine

COPY --from=build /app/build /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

The first stage uses Node.js to compile the React application.

```text
React source
    │
    ▼
npm run build
    │
    ▼
Static HTML/CSS/JavaScript
```

The final container does not need Node.js.

Nginx serves the static React build from:

```text
/usr/share/nginx/html
```

So the final production container is approximately:

```text
Nginx
  │
  └── React static files
```

This taught me the purpose of **multi-stage Docker builds**.

---

# Nginx Reverse Proxy

Nginx performs two jobs:

1. Serves the compiled React application
2. Proxies API requests to the backend container

For example:

```nginx
location /api/ {
    proxy_pass http://backend:8080/;
}
```

The request flow becomes:

```text
Browser
   │
   │ GET /api/users
   ▼
Nginx
   │
   │ Docker DNS resolves "backend"
   ▼
backend:8080
```

This allows the browser to communicate with one public endpoint while Nginx forwards API traffic internally.

---

# Backend Container

The backend is a Node.js service running on port `8080`.

Its database configuration is similar to:

```env
PORT=8080

DB_HOST=mysql
DB_PORT=3306
DB_NAME=nodeapp
DB_USER=nodeuser
DB_PASSWORD=mypassword

JWT_SECRET=change_this_to_a_long_random_secret
JWT_EXPIRES_IN=1d
```

The important part is:

```env
DB_HOST=mysql
```

The backend does not use:

```env
DB_HOST=localhost
```

inside Docker Compose.

`localhost` inside the backend container refers to the backend container itself.

Instead, Docker's internal DNS resolves the Compose service name:

```text
mysql
  │
  ▼
MySQL container IP
```

---

# Docker Networking

Before Docker Compose, I manually created a Docker network:

```bash
docker network create nodeapp-network
```

Containers attached to the same custom Docker network can communicate using container or service names instead of hard-coded IP addresses.

For example:

```text
backend
   │
   │ mysql:3306
   ▼
mysql container
```

This is better than using container IP addresses because container IPs may change.

With Docker Compose, this networking is created automatically.

```text
docker compose up
       │
       ▼
Compose creates a default network
       │
       ├── frontend
       ├── backend
       └── mysql
```

---

# Docker Volumes

MySQL data is persisted using a named Docker volume.

```yaml
volumes:
  mysql_data:
```

The MySQL service mounts it at:

```yaml
volumes:
  - mysql_data:/var/lib/mysql
```

This separates database data from the lifecycle of the MySQL container.

```text
MySQL container
      │
      ▼
/var/lib/mysql
      │
      ▼
Docker volume
```

The container can be recreated while the database data remains.

A command such as:

```bash
docker compose down
```

does not normally remove the named volume.

However:

```bash
docker compose down -v
```

removes the volume and can destroy the stored database data.

---

# Docker Compose

After learning Docker manually, the next step was Docker Compose.

Instead of manually running:

```bash
docker run ...
docker run ...
docker run ...
```

the full application infrastructure is described in one file.

Example:

```yaml
services:
  mysql:
    image: mysql:8.4

    environment:
      MYSQL_DATABASE: nodeapp
      MYSQL_USER: nodeuser
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}

    volumes:
      - mysql_data:/var/lib/mysql

  backend:
    image: ${ECR_REGISTRY}/nodeapp-backend:${IMAGE_TAG}

    environment:
      PORT: 8080
      DB_HOST: mysql
      DB_PORT: 3306
      DB_NAME: nodeapp
      DB_USER: nodeuser
      DB_PASSWORD: ${DB_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}
      JWT_EXPIRES_IN: 1d
      CORS_ORIGIN: "*"

    depends_on:
      - mysql

  frontend:
    image: ${ECR_REGISTRY}/nodeapp-frontend:${IMAGE_TAG}

    depends_on:
      - backend

    ports:
      - "80:80"

volumes:
  mysql_data:
```

Docker Compose manages:

- Container creation
- Container networking
- Volumes
- Environment variables
- Service dependencies
- Port mappings
- Application startup

---

# Stage 3 — Manual AWS EC2 Deployment

The next step was deploying the application to AWS.

A single EC2 instance was created and used as the application server.

The EC2 server runs:

```text
Docker Engine
Docker Compose
```

and hosts all three containers:

```text
EC2
├── frontend / Nginx
├── backend / Node.js
└── MySQL
```

The EC2 Security Group exposes:

```text
22  → SSH from my IP
80  → HTTP from the internet
```

The following ports are not publicly exposed:

```text
8080 → backend
3306 → MySQL
```

The initial deployment process was completely manual.

```text
GitHub
   │
   │ git clone / git pull
   ▼
EC2
   │
   ├── docker compose build
   └── docker compose up -d
```

This was intentionally done before CI/CD so I could understand exactly what the automated pipeline would later replace.

---

# Stage 4 — Amazon ECR

The next step was separating **building Docker images** from **running Docker containers**.

Two private Amazon ECR repositories were created:

```text
nodeapp-frontend
nodeapp-backend
```

MySQL is not stored in my ECR because it uses the official upstream image:

```text
mysql:8.4
```

The new architecture became:

```text
Build Machine
     │
     ├── docker build
     ├── docker tag
     └── docker push
            │
            ▼
       Amazon ECR
      ┌─────┴─────┐
      ▼           ▼
frontend        backend
 image           image
      └─────┬─────┘
            │
            ▼
           EC2
            │
            ├── docker compose pull
            └── docker compose up -d
```

This introduced an important concept:

```text
BUILD
```

and:

```text
RUN / DEPLOY
```

should be treated as separate responsibilities.

---

# Docker Image Versioning

Initially, Docker images were manually tagged:

```text
v1
v2
```

Later, CI uses the Git commit SHA.

For example:

```text
Git commit:
8f3a2cd
```

produces:

```text
nodeapp-frontend:8f3a2cd
nodeapp-backend:8f3a2cd
```

This creates a direct relationship between source code and the deployed Docker artifact.

```text
Git commit
8f3a2cd
    │
    ├── frontend image
    └── backend image
```

This also makes rollback easier because older image versions remain available in ECR.

---

# IAM Role for EC2

The EC2 instance should not store permanent AWS access keys.

Instead, an IAM role is attached directly to the instance.

The role allows EC2 to:

- Pull images from Amazon ECR
- Communicate with AWS Systems Manager

Conceptually:

```text
EC2
 │
 ▼
IAM Role
 │
 ├── ECR pull permission
 └── SSM managed-instance permission
```

This taught me the difference between:

```text
Authentication
```

and:

```text
Authorization
```

AWS first identifies the caller and then checks whether that identity is allowed to perform the requested action.

---

# Stage 5 — GitHub Actions Continuous Integration

The next step was automating the Docker build and ECR push process with GitHub Actions.

The workflow lives in:

```text
.github/workflows/ci.yml
```

A push to the `main` branch triggers the CI workflow.

```text
git push
   │
   ▼
GitHub Actions
   │
   ├── Checkout repository
   ├── Install dependencies
   ├── Run tests
   ├── Build frontend image
   ├── Build backend image
   ├── Authenticate to AWS
   ├── Login to ECR
   └── Push Docker images
```

At this stage deployment to EC2 was still manual.

This made the CI/CD boundary clear.

---

# Continuous Integration vs Continuous Deployment

## Continuous Integration

```text
Source code
    │
    ▼
Tests
    │
    ▼
Docker build
    │
    ▼
Docker images
    │
    ▼
Amazon ECR
```

The purpose is to verify and package code into a deployable artifact.

## Continuous Deployment

```text
Amazon ECR
    │
    ▼
EC2
    │
    ▼
docker compose pull
    │
    ▼
docker compose up -d
    │
    ▼
Production
```

The purpose is to take a validated artifact and run it in the production environment.

---

# GitHub OIDC Authentication with AWS

Instead of storing permanent AWS access keys in GitHub Secrets, the workflow uses **OpenID Connect (OIDC)**.

Conceptually:

```text
GitHub Actions
      │
      │ OIDC token
      ▼
AWS STS
      │
      ▼
IAM Role
      │
      ▼
Temporary AWS credentials
```

This avoids storing long-lived credentials such as:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

inside GitHub.

The AWS IAM trust policy is restricted so that only the intended GitHub repository and branch can assume the role.

Example identity condition:

```text
repo:<github-user>/<repository>:ref:refs/heads/main
```

---

# GitHub Actions CI Workflow

The CI workflow performs the same steps that were previously executed manually.

Example structure:

```yaml
name: NodeApp CI/CD

on:
  push:
    branches:
      - main

permissions:
  contents: read
  id-token: write

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v6

      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build images
        run: |
          docker build ...
          docker build ...

      - name: Push images
        run: |
          docker push ...
          docker push ...
```

The workflow tags images using:

```text
${{ github.sha }}
```

so each build is associated with the Git commit that produced it.

---

# Stage 6 — Complete CI/CD Deployment

The final step was automating the EC2 deployment.

Instead of GitHub connecting to EC2 using SSH and storing an SSH private key, the pipeline uses **AWS Systems Manager Run Command**.

The architecture is:

```text
Developer
    │
    │ git push
    ▼
GitHub
    │
    ▼
GitHub Actions
    │
    ├── Test
    ├── Build
    ├── Push Docker images
    │          │
    │          ▼
    │      Amazon ECR
    │
    └── Deploy
            │
            ▼
        AWS Systems
          Manager
            │
            ▼
           EC2
            │
            ├── docker compose pull
            └── docker compose up -d
                    │
                    ▼
                Production
```

This means the CI/CD system does not need the EC2 SSH private key.

---

# EC2 Deployment Script

The EC2 instance contains a deployment script similar to:

```bash
#!/usr/bin/env bash

set -euo pipefail

IMAGE_TAG="$1"

APP_DIR="/opt/nodeapp"
AWS_REGION="<aws-region>"
ECR_REGISTRY="<account-id>.dkr.ecr.<aws-region>.amazonaws.com"

cd "$APP_DIR"

aws ecr get-login-password \
  --region "$AWS_REGION" \
| docker login \
  --username AWS \
  --password-stdin \
  "$ECR_REGISTRY"

if grep -q '^IMAGE_TAG=' .env; then
    sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$IMAGE_TAG/" .env
else
    echo "IMAGE_TAG=$IMAGE_TAG" >> .env
fi

docker compose pull

docker compose up -d --remove-orphans

docker compose ps
```

The script accepts a Git commit SHA:

```bash
/opt/nodeapp/deploy.sh 8f3a2cd
```

and deploys the corresponding images from ECR.

---

# Complete CI/CD Flow

The final deployment flow is now:

```text
1. Developer changes code
        │
        ▼
2. git commit
        │
        ▼
3. git push main
        │
        ▼
4. GitHub Actions starts
        │
        ▼
5. Tests run
        │
        ▼
6. Docker images build
        │
        ▼
7. GitHub authenticates to AWS using OIDC
        │
        ▼
8. Images are pushed to ECR
        │
        ▼
9. Images are tagged using the Git commit SHA
        │
        ▼
10. Deploy job runs
        │
        ▼
11. GitHub sends an SSM command to EC2
        │
        ▼
12. EC2 runs deploy.sh <commit-sha>
        │
        ▼
13. EC2 authenticates to ECR
        │
        ▼
14. docker compose pull
        │
        ▼
15. docker compose up -d
        │
        ▼
16. New version is live
```

The only command needed from the developer is:

```bash
git push origin main
```

---

# Artifact-Based Deployment

One of the most important concepts learned in this project is that production should run the exact Docker artifact produced by CI.

The flow is:

```text
Commit
  │
  ▼
CI
  │
  ▼
Docker image
  │
  ▼
ECR
  │
  ▼
Production
```

EC2 no longer needs to:

```text
git pull
docker build
```

during a normal application deployment.

Instead it only needs to pull the already-built Docker image.

This means:

```text
Build once
Run the same artifact
```

---

# Rollback

Because images are tagged using Git commit SHAs, previous deployments remain available.

For example:

```text
ECR

frontend:81bd3ae
backend:81bd3ae

frontend:a84f21c
backend:a84f21c
```

If:

```text
a84f21c
```

has a problem, production can be rolled back by deploying:

```bash
/opt/nodeapp/deploy.sh 81bd3ae
```

There is no need to rebuild the old source code.

---

# Failure Protection

The deployment job depends on the CI job.

Conceptually:

```text
Tests
  │
  ├── FAIL
  │      │
  │      └── deployment stops
  │
  └── PASS
         │
         ▼
       Build
         │
         ▼
       Push
         │
         ▼
       Deploy
```

A failed CI job prevents the deployment job from running.

This means broken code should not automatically reach production.

---

# AWS Security Model Used

The pipeline currently uses two different IAM roles.

## EC2 IAM Role

Used by the application server.

Responsibilities:

```text
EC2
 ├── Pull images from ECR
 └── Communicate with Systems Manager
```

## GitHub Actions IAM Role

Used by GitHub through OIDC.

Responsibilities:

```text
GitHub Actions
 ├── Push Docker images to ECR
 └── Send deployment commands through SSM
```

This separation helps follow the principle of least privilege.

---

# Environment Variables and Secrets

Application secrets are not stored directly in the Docker image.

The production EC2 server keeps environment-specific configuration separately.

Example:

```env
IMAGE_TAG=8f3a2cd

DB_PASSWORD=...
MYSQL_ROOT_PASSWORD=...
JWT_SECRET=...
```

The Compose file references them:

```yaml
DB_PASSWORD: ${DB_PASSWORD}
JWT_SECRET: ${JWT_SECRET}
```

The `.env` file should not be committed.

```gitignore
.env
```

In a more advanced architecture these values could be moved to:

- AWS Secrets Manager
- AWS Systems Manager Parameter Store

---

# Commands Learned

## Docker

```bash
docker build
docker images
docker run
docker ps
docker logs
docker pull
docker push
docker tag
docker network ls
docker network inspect
docker volume ls
```

## Docker Compose

```bash
docker compose config
docker compose build
docker compose up -d
docker compose ps
docker compose logs
docker compose logs -f
docker compose pull
docker compose down
```

## AWS CLI / ECR

```bash
aws sts get-caller-identity

aws ecr get-login-password \
  --region <region> \
| docker login \
  --username AWS \
  --password-stdin \
  <ecr-registry>
```

## Git

```bash
git add .
git commit -m "message"
git push origin main
```

---

# Technologies Used

| Technology          | Purpose                             |
| ------------------- | ----------------------------------- |
| React               | Frontend application                |
| Node.js             | Backend API                         |
| MySQL               | Relational database                 |
| Nginx               | Static web server and reverse proxy |
| Vagrant             | Initial VM-based environment        |
| Docker              | Application containerization        |
| Docker Compose      | Multi-container orchestration       |
| GitHub              | Source control                      |
| GitHub Actions      | CI/CD automation                    |
| AWS EC2             | Application compute/server          |
| Amazon ECR          | Docker image registry               |
| AWS IAM             | Authentication and authorization    |
| GitHub OIDC         | Short-lived AWS authentication      |
| AWS Systems Manager | Remote deployment execution         |

---

# Key Concepts Learned

This project helped me understand that DevOps tools have different responsibilities.

```text
GitHub
    Source control

GitHub Actions
    CI/CD orchestration

Docker
    Package the application

Amazon ECR
    Store deployable Docker images

AWS EC2
    Run the application

Docker Compose
    Manage the application containers

IAM
    Define access permissions

OIDC
    Authenticate GitHub to AWS without permanent AWS keys

AWS Systems Manager
    Execute deployment commands remotely

Nginx
    Public web entry point and reverse proxy

MySQL
    Persistent application database
```

The biggest lesson was understanding the full lifecycle:

```text
Code
  ↓
Test
  ↓
Build
  ↓
Artifact
  ↓
Registry
  ↓
Deployment
  ↓
Runtime
```

---

# Current Architecture

```text
                         Developer
                             │
                             │ git push
                             ▼
                         GitHub
                             │
                             ▼
                     GitHub Actions
                             │
                    ┌────────┴────────┐
                    │                 │
                    ▼                 ▼
                  Tests          Docker Build
                                      │
                            ┌─────────┴─────────┐
                            ▼                   ▼
                    frontend image       backend image
                            │                   │
                            └─────────┬─────────┘
                                      │
                                      ▼
                                  Amazon ECR
                                      │
                                      │
                             GitHub Actions CD
                                      │
                                      ▼
                           AWS Systems Manager
                                      │
                                      ▼
                               ┌─────────────┐
                               │   AWS EC2   │
                               │             │
                               │   Docker    │
                               │   Compose   │
                               │             │
Internet ─────────────────────►│ Nginx/React │
                               │      │      │
                               │      ▼      │
                               │   Node.js   │
                               │      │      │
                               │      ▼      │
                               │    MySQL    │
                               │             │
                               └─────────────┘
```

---

# What I Have Achieved

By completing this project, I have:

- Started with a Vagrant-based VM environment
- Containerized a React application
- Used a multi-stage Docker build
- Served the React production build with Nginx
- Containerized a Node.js backend
- Connected Node.js to a MySQL container
- Used Docker DNS instead of container IP addresses
- Created and used Docker networks
- Persisted database data with Docker volumes
- Replaced manual container commands with Docker Compose
- Deployed the complete stack manually to AWS EC2
- Configured EC2 Security Groups
- Created private Amazon ECR repositories
- Built, tagged, pushed, and pulled Docker images manually
- Separated image build responsibilities from application runtime
- Used IAM roles instead of storing AWS credentials on EC2
- Created a GitHub Actions CI workflow
- Authenticated GitHub Actions to AWS using OIDC
- Automatically built and published images to ECR
- Tagged images using Git commit SHAs
- Used AWS Systems Manager instead of SSH for automated deployment
- Created an EC2 deployment script
- Built a complete CI/CD pipeline from Git push to production
- Implemented artifact-based deployment
- Learned how image versioning enables rollback

---

# Next Steps

The current GitHub Actions pipeline is complete for the first architecture.

The next learning objective is to recreate the same pipeline using **Jenkins** while keeping the application infrastructure unchanged.

The planned Jenkins architecture is:

```text
GitHub
   │
   ▼
Jenkins
   │
   ├── Test
   ├── Docker build
   ├── Push to ECR
   └── Deploy
          │
          ▼
         EC2
```

This will make it possible to compare:

```text
GitHub Actions
       vs
Jenkins
```

while continuing to use:

- Docker
- Docker Compose
- Amazon ECR
- AWS EC2
- IAM
- Systems Manager

After Jenkins, possible future improvements include:

- HTTPS
- Domain configuration with Route 53
- Application Load Balancer
- AWS Secrets Manager
- Systems Manager Parameter Store
- Amazon RDS instead of running MySQL on EC2
- Terraform
- ECS
- Kubernetes
- Automated health checks and rollback
- Separate staging and production environments

---

# Status

**Current milestone: complete Docker-based GitHub Actions CI/CD deployment to AWS EC2.**

```text
git push
   ↓
GitHub Actions
   ↓
Test
   ↓
Docker Build
   ↓
Amazon ECR
   ↓
AWS Systems Manager
   ↓
EC2
   ↓
Docker Compose
   ↓
React + Node.js + MySQL
```
