# AWS Infrastructure as Code: Terraform & CloudFormation

> **Infrastructure as Code** 

Provision a secure, multi-tier AWS network using **Terraform** and **AWS CloudFormation** — two industry-standard IaC approaches implemented side-by-side for direct comparison.

**Scope:**
- **VPC** with Public and Private Subnets, Internet Gateway, and a default Security Group
- **Route Tables** — Public RT routes traffic via IGW; Private RT routes via NAT Gateway
- **NAT Gateway** — lets Private Subnet instances reach the internet without inbound exposure
- **EC2 Instances** — a publicly accessible bastion host and a private workload node reachable only through it via SSH
- **Security Groups** — Public EC2 allows SSH from a specific IP only; Private EC2 allows inbound only from the Public EC2

## Architecture

```
Internet
    │
    ▼
Internet Gateway
    │
    ▼
┌─────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                      │
│                                         │
│  ┌───────────────────┐                  │
│  │  Public Subnet    │  ◄── Public RT   │
│  │  10.0.1.0/24      │      (→ IGW)     │
│  │                   │                  │
│  │  [Bastion EC2]    │                  │
│  │  [NAT Gateway]    │                  │
│  └───────────────────┘                  │
│           │ NAT                         │
│           ▼                             │
│  ┌───────────────────┐                  │
│  │  Private Subnet   │  ◄── Private RT  │
│  │  10.0.2.0/24      │      (→ NAT GW)  │
│  │                   │                  │
│  │  [Private EC2]    │                  │
│  └───────────────────┘                  │
└─────────────────────────────────────────┘
```

**Resources provisioned:**
- VPC with public and private subnets across a single AZ
- Internet Gateway + NAT Gateway for outbound internet access from private subnet
- Security Groups with least-privilege SSH rules
- Two EC2 instances (Ubuntu 24.04 LTS) — public bastion and private workload node
- SSH ProxyJump configuration for secure access to the private instance

## Tech Stack

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | >= 1.0 | Modular IaC (Part 1) |
| AWS CloudFormation | — | Declarative YAML stacks (Part 2) |
| AWS CLI | >= 2.x | Deployment & querying |
| Ubuntu Server | 24.04 LTS | EC2 AMI |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0 installed
- [AWS CLI](https://aws.amazon.com/cli/) configured (`aws configure`)
- IAM user with the following managed policies:

| Policy | Required for |
|--------|-------------|
| `AmazonEC2FullAccess` | EC2, Key Pairs, Security Groups |
| `AmazonVPCFullAccess` | VPC, Subnets, IGW, NAT, Route Tables |
| `AWSCloudFormationFullAccess` | CloudFormation stacks only |

---

## Part 1 — Terraform

### Project Structure

```
Terraform/
├── main.tf              # Root module — wires up child modules
├── variables.tf         # Input variable declarations
├── outputs.tf           # Stack outputs
├── terraform.tfvars     # Variable values (editable)
└── modules/
    ├── vpc/             # VPC, Subnets, IGW, NAT, Route Tables
    ├── security_groups/ # Security Group rules
    └── ec2/             # EC2 instances + SSH key pair
```

### Configuration (`terraform.tfvars`)

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `ap-southeast-1` | AWS region |
| `project_name` | `your-project` | Resource name prefix |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `public_subnet_cidr` | `10.0.1.0/24` | Public subnet CIDR |
| `private_subnet_cidr` | `10.0.2.0/24` | Private subnet CIDR |
| `availability_zone` | `ap-southeast-1a` | Target AZ |
| `ssh_allowed_cidr` | `0.0.0.0/0` | CIDR allowed to SSH to bastion |
| `ami` | _(auto-resolved)_ | Leave blank to use latest Ubuntu 24.04 LTS |
| `instance_type` | `t3.micro` | EC2 instance type |

### Deploy

```bash
cd Terraform

# Initialize providers and modules
terraform init

# Preview changes
terraform plan

# Apply (type 'yes' to confirm)
terraform apply
```

### Outputs

After `apply` succeeds, Terraform prints:

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC resource ID |
| `public_ec2_ip` | Public IP of the bastion host |
| `private_ec2_private_ip` | Private IP of the workload node |
| `ssh_to_public` | Ready-to-run SSH command for bastion |
| `ssh_to_private_via_proxy` | SSH command tunneled through bastion |

The SSH key file `your-key.pem` is auto-generated in `Terraform/`.

### Connect via SSH

```bash
# Bastion host
ssh -i Terraform/your-key.pem ubuntu@<public_ec2_ip>

# Private node through bastion (ProxyCommand forwards the key for both hops)
ssh -i Terraform/your-key.pem \
  -o "ProxyCommand=ssh -i Terraform/your-key.pem -W %h:%p ubuntu@<public_ec2_ip>" \
  ubuntu@<private_ec2_private_ip>
```

### Teardown

```bash
terraform destroy   # type 'yes' to confirm
```

---

## Part 2 — CloudFormation

### Project Structure

```
CloudFormation/
├── 01-vpc.yaml              # VPC, Subnets, IGW, NAT Gateway, Route Tables
├── 02-security-groups.yaml  # Security Groups
└── 03-ec2.yaml              # EC2 Instances
```

Three independent stacks are linked via CloudFormation `Outputs` / `!ImportValue`. Each stack exports resource IDs consumed by the next, enforcing a clean dependency chain without tight coupling.

### Create SSH Key Pair

**Linux / macOS:**
```bash
aws ec2 create-key-pair \
  --key-name your-key \
  --region ap-southeast-1 \
  --query 'KeyMaterial' \
  --output text > your-key.pem

chmod 400 your-key.pem
```

**Windows (PowerShell):**
```powershell
aws ec2 create-key-pair `
  --key-name your-key `
  --region ap-southeast-1 `
  --query 'KeyMaterial' `
  --output text | Out-File -Encoding ascii your-key.pem

icacls your-key.pem /inheritance:r /grant:r "${env:USERNAME}:R"
```

### Deploy Stacks (in order)

**Stack 1 — VPC**
```powershell
aws cloudformation deploy `
  --template-file CloudFormation/01-vpc.yaml `
  --stack-name your-project-vpc `
  --region ap-southeast-1 `
  --parameter-overrides `
    ProjectName=your-project `
    VpcCidr=10.0.0.0/16 `
    PublicSubnetCidr=10.0.1.0/24 `
    PrivateSubnetCidr=10.0.2.0/24 `
    AvailabilityZone=ap-southeast-1a
```

**Stack 2 — Security Groups** (after Stack 1 completes)
```powershell
aws cloudformation deploy `
  --template-file CloudFormation/02-security-groups.yaml `
  --stack-name your-project-security-groups `
  --region ap-southeast-1 `
  --parameter-overrides `
    ProjectName=your-project `
    SshAllowedCidr=0.0.0.0/0
```

**Stack 3 — EC2 Instances** (after Stack 2 completes)
```powershell
aws cloudformation deploy `
  --template-file CloudFormation/03-ec2.yaml `
  --stack-name your-project-ec2 `
  --region ap-southeast-1 `
  --parameter-overrides `
    ProjectName=your-project `
    KeyPairName=your-key `
    InstanceType=t3.micro
```

### Get Instance IPs

```powershell
aws cloudformation describe-stacks `
  --stack-name your-project-ec2 `
  --region ap-southeast-1 `
  --query 'Stacks[0].Outputs'
```

### Connect via SSH

```powershell
# Bastion host
ssh -i your-key.pem ubuntu@<PublicEC2PublicIp>

# Private node through bastion
ssh -i your-key.pem `
  -o "ProxyCommand=ssh -i your-key.pem -W %h:%p ubuntu@<PublicEC2PublicIp>" `
  ubuntu@<PrivateEC2PrivateIp>
```

### Teardown (reverse order)

```powershell
aws cloudformation delete-stack --stack-name your-project-ec2 --region ap-southeast-1

# Wait for deletion, then:
aws cloudformation delete-stack --stack-name your-project-security-groups --region ap-southeast-1

# Wait for deletion, then:
aws cloudformation delete-stack --stack-name your-project-vpc --region ap-southeast-1
```

---

## Key Takeaways

- **Terraform modules** enable reusable, testable infrastructure components — vpc, security_groups, and ec2 are independently versioned.
- **CloudFormation cross-stack references** (`!ImportValue`) enforce deployment ordering and decouple stack lifecycles.
- **NAT Gateway** provides outbound internet access for the private subnet without exposing it inbound.
- **SSH ProxyCommand** eliminates the need for a VPN — the bastion host acts as a secure jump point with key forwarding.
