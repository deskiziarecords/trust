# Determinus

[![CI](https://github.com/deskiziarecords/determinus/actions/workflows/ci.yml/badge.svg)](https://github.com/deskiziarecords/determinus/actions)
[![Security Audit](https://github.com/deskiziarecords/determinus/actions/workflows/audit.yml/badge.svg)](https://github.com/deskiziarecords/determinus/actions)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Rust Version](https://img.shields.io/badge/rust-1.75%2B-orange.svg)](https://rustup.rs)

**Deterministic Policy Enforcement for AI Systems**

Determinus is a formally-verified, constant-time middleware that enforces HIPAA compliance 
and safety constraints between AI agents and clients. Built in Rust. Designed for 
safety-critical deployment.

## Trust Model

| Component | Verification | Status |
|-----------|--------------|--------|
| Constant-time execution | `dudect` statistical testing | ✅ Verified |
| Memory safety | Rust compiler + Miri | ✅ Verified |
| Cryptographic primitives | `subtle` crate + formal review | ✅ Verified |
| Build reproducibility | SLSA Level 3 + Sigstore | ✅ Verified |
| Infrastructure | CIS Hardening + Terraform | ✅ Verified |

## Quick Start

```bash
# Install (x86_64 Linux)
curl -sSL https://api.determinus.rs/install.sh | bash

# Or build from source (reproducible)
git clone https://github.com/deskiziarecords/determinus.git
cd determinis && make build
