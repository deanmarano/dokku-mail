.PHONY: test test-unit test-integration lint shellcheck install clean help

# Default target
help:
	@echo "dokku-mail development commands:"
	@echo ""
	@echo "  make test             Run all tests"
	@echo "  make test-unit        Run unit tests only"
	@echo "  make test-integration Run integration tests only"
	@echo "  make lint             Run shellcheck on all scripts"
	@echo "  make install          Install plugin locally"
	@echo "  make clean            Clean up test artifacts"
	@echo ""

# Run all tests
test: test-unit test-integration

# Run unit tests
test-unit:
	@echo "Running unit tests..."
	@if [ -d tests/unit ] && [ "$$(ls -A tests/unit/*.bats 2>/dev/null)" ]; then \
		bats tests/unit/*.bats; \
	else \
		echo "No unit tests found"; \
	fi

# Run integration tests
test-integration:
	@echo "Running integration tests..."
	@if [ -d tests/integration ] && [ "$$(ls -A tests/integration/*.bats 2>/dev/null)" ]; then \
		bats tests/integration/*.bats; \
	else \
		echo "No integration tests found"; \
	fi

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=tests/integration/test_foo.bats"; \
		exit 1; \
	fi
	bats $(FILE)

# Lint all shell scripts
lint: shellcheck

shellcheck:
	@echo "Running shellcheck..."
	@shellcheck -x commands config install
	@shellcheck -x subcommands/*
	@shellcheck -x providers/*/provider.sh
	@echo "Shellcheck passed!"

# Install plugin for local development
install:
	@echo "Installing plugin..."
	@sudo dokku plugin:install file://$$(pwd) --name mail || \
		sudo dokku plugin:update mail

# Uninstall plugin
uninstall:
	@echo "Uninstalling plugin..."
	@sudo dokku plugin:uninstall mail || true

# Clean up test artifacts
clean:
	@echo "Cleaning up..."
	@docker ps -aq -f "name=dokku.mail.test-" | xargs -r docker rm -f 2>/dev/null || true
	@echo "Cleaned up test containers"

# Update git submodules (bats helpers)
submodules:
	@git submodule update --init --recursive

# Format/check bash scripts (requires shfmt)
fmt:
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -w -i 2 commands config install subcommands/* providers/*/provider.sh; \
	else \
		echo "shfmt not installed, skipping formatting"; \
	fi

# Check formatting without modifying
fmt-check:
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -d -i 2 commands config install subcommands/* providers/*/provider.sh; \
	else \
		echo "shfmt not installed, skipping format check"; \
	fi
