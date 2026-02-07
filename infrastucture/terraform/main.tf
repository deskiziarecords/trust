terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "determinus-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# Hetzner Cloud - Primary enforcement engine (GDPR jurisdiction)
provider "hcloud" {
  token = var.hetzner_token
}

# AWS - Backup region + KMS for key escrow
provider "aws" {
  alias  = "backup"
  region = "eu-west-1" # Ireland - also GDPR
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Primary server - Dedicated vCPU for constant-time guarantees
resource "hcloud_server" "determinus_primary" {
  name        = "determinus-prod-01"
  server_type = "ccx23" # Dedicated CPU, 4 vCPU, 16GB RAM
  image       = "ubuntu-22.04"
  location    = "fsn1" # Falkenstein, Germany
  
  labels = {
    environment = "production"
    purpose     = "policy-enforcement"
    compliance  = "hipaa-gdpr-ready"
  }

  # Immutable infrastructure - never modify, only replace
  lifecycle {
    prevent_destroy = true
    replace_triggered_by = [
      hcloud_volume.audit_log.id
    ]
  }
}

# Encrypted volume for audit logs (separate from root)
resource "hcloud_volume" "audit_log" {
  name      = "determinus-audit-prod"
  size      = 100 # GB
  server_id = hcloud_server.determinus_primary.id
  format    = "ext4"
  
  labels = {
    encryption = "luks-aes256-xts"
    backup     = "cross-region-required"
  }
}

# Firewall - Zero trust, explicit allow only
resource "hcloud_firewall" "determinus" {
  name = "determinus-prod-firewall"

  # Cloudflare IPs only for HTTPS
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks
    description = "Cloudflare proxy only"
  }

  # WireGuard/Tailscale mesh VPN for admin
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "51820"
    source_ips = [] # Populated from Tailscale ACL
    description = "WireGuard mesh VPN"
  }

  # Explicit deny all else (implicit in Hetzner, but documented)
}

# Cloudflare DNS + Security
resource "cloudflare_record" "determinus" {
  zone_id = var.cloudflare_zone_id
  name    = "api"
  value   = hcloud_server.determinus_primary.ipv4_address
  type    = "A"
  proxied = true
  
  comment = "Determinus Policy Enforcement API"
}

# DNSSEC - Because we understand supply chain attacks start at DNS
resource "cloudflare_zone_dnssec" "determinus" {
  zone_id = var.cloudflare_zone_id
}

# CAA Records - Only Let's Encrypt, no rogue CAs
resource "cloudflare_record" "caa_le" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain
  type    = "CAA"
  data {
    flags = "0"
    tag   = "issue"
    value = "letsencrypt.org; validationmethods=dns-01"
  }
}

resource "cloudflare_record" "caa_iodef" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain
  type    = "CAA"
  data {
    flags = "0"
    tag   = "iodef"
    value = "mailto:security@${var.domain}"
  }
}

# AWS Backup - Cross-region, encrypted, air-gapped feel
resource "aws_s3_bucket" "audit_backup" {
  provider = aws.backup
  bucket   = "determinus-audit-backup-${random_id.bucket_suffix.hex}"
  
  object_lock_enabled = true # WORM (Write Once Read Many)
  
  tags = {
    Compliance = "HIPAA"
    DataClass  = "PHI-Audit-Logs"
  }
}

resource "aws_s3_bucket_versioning" "audit_backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.audit_backup.id
  versioning_configuration {
    status = "Enabled"
    mfa_delete = "Enabled" # Require MFA for deletion
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "audit_backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.audit_backup.id
  
  rule {
    id     = "glacier-transition"
    status = "Enabled"
    
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    
    noncurrent_version_transition {
      noncurrent_days = 7
      storage_class   = "DEEP_ARCHIVE"
    }
  }
}

# Outputs for CI/CD
output "server_ip" {
  value     = hcloud_server.determinus_primary.ipv4_address
  sensitive = false
}

output "audit_volume_id" {
  value = hcloud_volume.audit_log.id
}
