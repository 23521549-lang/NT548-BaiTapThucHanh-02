#!/bin/bash
set -euo pipefail
exec > /var/log/userdata.log 2>&1

echo "===== NT548 Cau3: Installing Jenkins + Docker + SonarQube ====="

# ── Cập nhật hệ thống ──
yum update -y
yum install -y git curl wget unzip

# ── Cài Java 17 (Jenkins yêu cầu) ──
amazon-linux-extras enable corretto17 2>/dev/null || true
yum install -y java-17-amazon-corretto-headless 2>/dev/null || \
  yum install -y java-17-openjdk-headless 2>/dev/null || true
java -version

# ── Cài Jenkins ──
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
yum install -y jenkins
systemctl enable jenkins
systemctl start jenkins
echo "Jenkins installed."

# ── Cài Docker ──
yum install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker jenkins
usermod -aG docker ec2-user

# ── Cài Docker Compose v2 ──
COMPOSE_VERSION="2.27.0"
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
docker compose version

# ── Docker Hub login ──
echo "${dockerhub_password}" | docker login --username "${dockerhub_username}" --password-stdin
echo "Docker Hub login done."

# ── Tạo thư mục làm việc ──
mkdir -p /opt/nt548
chown -R jenkins:jenkins /opt/nt548

# ── Chạy SonarQube bằng Docker Compose ──
cat > /opt/nt548/docker-compose-sonar.yml <<'SONAR_EOF'
version: "3.8"
services:
  sonarqube:
    image: sonarqube:10-community
    container_name: sonarqube
    restart: unless-stopped
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonar-db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar_pass
    ports:
      - "9000:9000"
    volumes:
      - sonar_data:/opt/sonarqube/data
      - sonar_logs:/opt/sonarqube/logs
      - sonar_extensions:/opt/sonarqube/extensions
    depends_on:
      - sonar-db
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

  sonar-db:
    image: postgres:15
    container_name: sonar-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar_pass
      POSTGRES_DB: sonar
    volumes:
      - sonar_postgres:/var/lib/postgresql/data

volumes:
  sonar_data:
  sonar_logs:
  sonar_extensions:
  sonar_postgres:
SONAR_EOF

# vm.max_map_count cần thiết cho SonarQube/Elasticsearch
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" >> /etc/sysctl.conf

docker compose -f /opt/nt548/docker-compose-sonar.yml up -d
echo "SonarQube started."

# ── Lấy Jenkins initial admin password và lưu vào file dễ đọc ──
sleep 30
JENKINS_PASS_FILE="/var/lib/jenkins/secrets/initialAdminPassword"
if [ -f "$JENKINS_PASS_FILE" ]; then
  echo "Jenkins initial password: $(cat $JENKINS_PASS_FILE)" > /opt/nt548/jenkins-initial-password.txt
  chmod 644 /opt/nt548/jenkins-initial-password.txt
fi

echo "===== Setup hoàn tất ====="
echo "Jenkins UI  : http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "SonarQube UI: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
