#!/bin/bash
set -e

# ==============================================================================
# Installs nginx on CentOS and configures it to reverse proxy to the
# React app running on 192.168.56.13:3000
# ==============================================================================

echo "==> Installing nginx..."
sudo yum install -y nginx

echo "==> Backing up original nginx.conf..."
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%Y%m%d%H%M%S)

echo "==> Writing new nginx.conf..."
sudo tee /etc/nginx/nginx.conf > /dev/null <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;

        location / {
            proxy_pass http://192.168.56.13:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
EOF

echo "==> Testing nginx configuration..."
sudo nginx -t

echo "==> Enabling and starting nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

echo "==> Done. nginx status:"
sudo systemctl status nginx --no-pager