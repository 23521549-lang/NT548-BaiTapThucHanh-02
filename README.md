# NT548 - Bài Tập Thực Hành 02

Quản lý và triển khai hạ tầng AWS và ứng dụng microservices với Terraform, CloudFormation, GitHub Actions, AWS CodePipeline và Jenkins.

## Cấu trúc thư mục

```
NT548-BaiTapThucHanh-02/
├── cau1/                          # Câu 1: Terraform + GitHub Actions + Checkov
│   ├── terraform/                 # IaC modules (VPC, NAT, RT, SG, EC2)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── terraform.tfvars.example
│   │   └── modules/
│   │       ├── vpc/
│   │       ├── nat_gateway/
│   │       ├── route_tables/
│   │       ├── security_groups/
│   │       └── ec2/
│   └── .github/workflows/
│       └── terraform.yml          # GitHub Actions: Checkov → Plan → Apply
│
├── cau2/                          # Câu 2: CloudFormation + CodePipeline
│   ├── cloudformation/
│   │   ├── templates/             # 5 CFN stacks
│   │   │   ├── vpc.yaml
│   │   │   ├── nat-gateway.yaml
│   │   │   ├── route-tables.yaml
│   │   │   ├── security-groups.yaml
│   │   │   └── ec2.yaml
│   │   ├── buildspec.yml          # CodeBuild: cfn-lint + taskcat
│   │   └── .taskcat.yml
│   └── codepipeline/              # Terraform tạo CodeCommit + CodeBuild + CodePipeline
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
│
├── cau3/                          # Câu 3: Jenkins + Online Boutique + SonarQube
│   ├── terraform/                 # Tạo EC2 Jenkins server
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── userdata.sh.tpl        # Tự cài Jenkins + Docker + SonarQube
│   │   └── terraform.tfvars.example
│   ├── jenkins/
│   │   └── Jenkinsfile            # Pipeline: Checkout → SonarQube → Build → Trivy → Push → Deploy
│   └── app/
│       └── docker-compose.yml     # Online Boutique 12 microservices
│
└── .gitignore
```

---

## Câu 1: Terraform + GitHub Actions + Checkov

### Cách chạy

```bash
cd cau1/terraform
cp terraform.tfvars.example terraform.tfvars
# Điền: aws_region, availability_zone, ami_id, key_pair_name, allowed_ssh_cidr

terraform init
terraform plan
terraform apply
```

### GitHub Actions (tự động)

Push lên nhánh `main` → tự động chạy pipeline:
1. **Checkov** — quét bảo mật IaC
2. **Terraform Validate + Plan**
3. **Terraform Apply** — yêu cầu manual approval (GitHub Environment: `production`)

**GitHub Secrets cần cấu hình** (Settings → Secrets → Actions):

| Secret | Mô tả |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key |
| `AWS_REGION` | VD: `ap-southeast-1` |
| `AWS_AZ` | VD: `ap-southeast-1a` |
| `AWS_AMI_ID` | AMI ID |
| `AWS_KEY_PAIR_NAME` | Tên Key Pair |
| `ALLOWED_SSH_CIDR` | IP của bạn `/32` |

**GitHub Variables** (Settings → Variables → Actions):

| Variable | Giá trị mặc định |
|----------|-----------------|
| `VPC_CIDR` | `10.0.0.0/16` |
| `PUBLIC_SUBNET_CIDR` | `10.0.1.0/24` |
| `PRIVATE_SUBNET_CIDR` | `10.0.2.0/24` |
| `INSTANCE_TYPE` | `t2.micro` |
| `PROJECT_NAME` | `nt548` |
| `ENVIRONMENT` | `dev` |

---

## Câu 2: CloudFormation + CodePipeline

### Bước 1: Tạo CodePipeline bằng Terraform

```bash
cd cau2/codepipeline
cp terraform.tfvars.example terraform.tfvars
# Điền tất cả biến

terraform init
terraform apply
```

Terraform sẽ tạo: CodeCommit repo + CodeBuild project + CodePipeline + S3 bucket + IAM roles.

### Bước 2: Push code lên CodeCommit

```bash
# Lấy clone URL từ terraform output
CLONE_URL=$(terraform output -raw codecommit_clone_url_http)

git clone $CLONE_URL nt548-cau2-infra
cd nt548-cau2-infra

# Copy toàn bộ thư mục cau2/cloudformation vào repo
cp -r ../NT548-BaiTapThucHanh-02/cau2 .
git add .
git commit -m "feat: add CloudFormation templates"
git push origin main
```

### Bước 3: Xem pipeline

```bash
terraform output pipeline_url
# Mở URL trong browser → xem CodePipeline chạy
```

**Pipeline flow:** CodeCommit push → CodeBuild (cfn-lint + taskcat) → Deploy VPC → Deploy NAT → Deploy RT + SG (song song) → Deploy EC2

---

## Câu 3: Jenkins + Online Boutique + SonarQube

### Bước 1: Tạo EC2 Jenkins server

```bash
cd cau3/terraform
cp terraform.tfvars.example terraform.tfvars
# Điền: aws_region, ami_id, key_pair_name, dockerhub_username, dockerhub_password

terraform init
terraform apply
```

> Dùng **t3.medium** hoặc lớn hơn — Jenkins + SonarQube cần ít nhất 4GB RAM.

Sau khi apply xong (~5 phút để user_data chạy xong):

```bash
# Lấy Jenkins password
$(terraform output -raw get_jenkins_password)

# Xem URLs
terraform output jenkins_url
terraform output sonarqube_url
```

### Bước 2: Cấu hình Jenkins

1. Mở Jenkins URL → nhập initial password
2. Cài plugins: **Pipeline**, **SonarQube Scanner**, **Docker Pipeline**, **Git**
3. **Manage Jenkins → Configure System → SonarQube servers**:
   - Name: `SonarQube`
   - URL: `http://localhost:9000`
   - Token: tạo tại SonarQube UI (Admin → My Account → Security)
4. **Credentials** → Add:
   - `dockerhub-credentials` (Username/Password)
   - `sonar-token` (Secret text)
5. **New Item → Pipeline** → paste nội dung `cau3/jenkins/Jenkinsfile`

### Bước 3: Cấu hình SonarQube

1. Mở SonarQube URL → đăng nhập `admin/admin` → đổi mật khẩu
2. **Projects → Create project** → key: `online-boutique`
3. **Administration → Webhooks → Create**:
   - URL: `http://localhost:8080/sonarqube-webhook/`

### Bước 4: Chạy pipeline

Jenkins UI → Build Now → xem logs từng stage.

**Pipeline stages:**
1. Checkout Online Boutique từ GitHub
2. SonarQube Analysis — phân tích chất lượng code
3. Quality Gate — kiểm tra ngưỡng chất lượng
4. Build Docker Images (frontend, cartservice, productcatalogservice)
5. Trivy Scan — quét lỗ hổng bảo mật
6. Push Images lên Docker Hub
7. Deploy bằng Docker Compose (12 microservices)
8. Smoke Test — kiểm tra frontend

**Kết quả:**
- Online Boutique: `http://<jenkins-ip>:8081`
- SonarQube report: `http://<jenkins-ip>:9000`

---

## Lưu ý chung

- Các file `terraform.tfvars` và `parameters.json` đã có trong `.gitignore` — không bao giờ commit lên Git
- Câu 1, 2, 3 là 3 hệ thống **độc lập** — không chạy cùng lúc để tránh tốn chi phí AWS
- Destroy sau khi demo: `terraform destroy` trong từng thư mục
