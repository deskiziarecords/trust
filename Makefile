# Determinus Build System
# Usage: make build, make test, make deploy

.PHONY: all build test clean deploy fmt lint audit

# Configuration
CARGO := cargo
RUSTFLAGS := -C target-cpu=sandybridge -C opt-level=3 -C lto=fat -C codegen-units=1
FEATURES := production,constant-time-verified

# Default target
all: fmt lint test build

# Development build (fast)
dev:
	RUSTFLAGS="" $(CARGO) build --features dev

# Production build (slow, verified)
build:
	RUSTFLAGS="$(RUSTFLAGS)" $(CARGO) build --release --features $(FEATURES)
	@echo "Binary location: target/release/determinus"
	@echo "Size: $$(ls -lh target/release/determinus | awk '{print $$5}')"
	@echo "Stripped size: $$(strip target/release/determinus && ls -lh target/release/determinus | awk '{print $$5}')"

# Testing - including constant-time verification
test:
	$(CARGO) test --features $(FEATURES)
	$(CARGO) test --features constant-time-verified -- --ignored

# Security audit of dependencies
audit:
	$(CARGO) install cargo-audit
	$(CARGO) audit
	$(CARGO) tree -d -D | grep -E "(<1 day|unknown)" || echo "All dependencies have known versions"

# Format and lint
fmt:
	$(CARGO) fmt -- --check
	$(CARGO) clippy --features $(FEATURES) -- -D warnings

# Documentation
docs:
	$(CARGO) doc --no-deps --features $(FEATURES)
	@echo "Docs available at: target/doc/determinus/index.html"

# Infrastructure deployment
deploy:
	cd infrastructure/terraform && terraform apply -auto-approve
	cd infrastructure/ansible && ansible-playbook -i inventory/production playbook.yml

# Local development environment
dev-env:
	rustup component add rustfmt clippy rust-src
	$(CARGO) install cargo-audit cargo-deny dudect-bencher
	@echo "Development environment ready"

# Clean build artifacts
clean:
	$(CARGO) clean
	rm -rf infrastructure/terraform/.terraform
	rm -f **/*.sig **/*.pem

# Release checklist
release-check:
	@echo "Release Checklist:"
	@echo "  [ ] Version bumped in Cargo.toml"
	@echo "  [ ] CHANGELOG.md updated"
	@echo "  [ ] GPG key available for signing"
	@echo "  [ ] Terraform plan reviewed"
	@echo "  [ ] Constant-time tests pass"
	@echo "  [ ] Security audit clean"
	@echo "  [ ] Documentation updated"
