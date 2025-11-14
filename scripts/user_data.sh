#!/bin/bash
set -euo pipefail

# Update base packages and install Docker from amazon-linux-extras to ensure service availability
yum update -y
amazon-linux-extras install docker -y
systemctl enable docker
systemctl start docker

# Add ec2-user to docker group for future convenience
usermod -a -G docker ec2-user || true

# Create custom index.html
cat >/home/ec2-user/index.html <<'EOF'
<html>
<head><title>Nginx on EC2</title></head>
<body>
  <h1>Hello from Nginx Docker on AWS EC2!</h1>
  <p>This web server is running in a Docker container on an AWS EC2 instance.</p>
</body>
</html>
EOF

# Create Dockerfile for custom Nginx image
cat >/home/ec2-user/Dockerfile <<'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EOF

# Build the custom Nginx Docker image
docker build -t custom-nginx /home/ec2-user

# Ensure any previous container is removed before running the new one
docker rm -f custom-nginx >/dev/null 2>&1 || true

# Run the container with restart policy so it survives reboots
docker run -d --name custom-nginx --restart unless-stopped -p 80:80 custom-nginx
