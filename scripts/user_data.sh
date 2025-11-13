#!/bin/bash
# Update and install Docker
yum update -y
yum install -y docker
service docker start
# Add ec2-user to docker group for future convenience
usermod -a -G docker ec2-user

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

# Build and run the custom Nginx Docker image
docker build -t custom-nginx /home/ec2-user
docker run -d --restart unless-stopped -p 80:80 custom-nginx
