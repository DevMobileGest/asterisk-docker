#############################################################################
# Makefile for FreePBX Docker
#
# Convenience commands for managing FreePBX Docker deployment
#############################################################################

.PHONY: help setup start stop restart logs logs-follow status clean renew-ssl validate build pull

# Default target
.DEFAULT_GOAL := help

# Colors for output
YELLOW := \033[1;33m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m # No Color

##@ General

help: ## Display this help message
	@echo "$(GREEN)FreePBX Docker Management$(NC)"
	@echo "======================================"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(YELLOW)<target>$(NC)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(GREEN)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup and Configuration

setup: ## Run initial setup wizard
	@echo "$(GREEN)Running FreePBX setup wizard...$(NC)"
	@bash SETUP.sh

validate: ## Validate docker-compose configuration
	@echo "$(GREEN)Validating docker-compose configuration...$(NC)"
	@docker-compose config --quiet && echo "$(GREEN)✓ Configuration is valid$(NC)" || echo "$(RED)✗ Configuration has errors$(NC)"

env: ## Create .env from .env.example (if not exists)
	@if [ ! -f .env ]; then \
		echo "$(GREEN)Creating .env file from template...$(NC)"; \
		cp .env.example .env; \
		echo "$(YELLOW)Please edit .env file and configure your settings$(NC)"; \
	else \
		echo "$(YELLOW).env file already exists$(NC)"; \
	fi

##@ Container Management

start: ## Start all containers
	@echo "$(GREEN)Starting FreePBX containers...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)✓ Containers started$(NC)"
	@make status

stop: ## Stop all containers
	@echo "$(YELLOW)Stopping FreePBX containers...$(NC)"
	@docker-compose down
	@echo "$(GREEN)✓ Containers stopped$(NC)"

restart: ## Restart all containers
	@echo "$(YELLOW)Restarting FreePBX containers...$(NC)"
	@docker-compose restart
	@echo "$(GREEN)✓ Containers restarted$(NC)"

status: ## Show container status
	@echo "$(GREEN)Container Status:$(NC)"
	@docker-compose ps

##@ Logs and Monitoring

logs: ## Show container logs (last 100 lines)
	@docker-compose logs --tail=100

logs-follow: ## Follow container logs in real-time
	@docker-compose logs -f

logs-server: ## Show FreePBX server logs
	@docker-compose logs --tail=100 server

logs-mariadb: ## Show MariaDB logs
	@docker-compose logs --tail=100 mariadb

##@ SSL Certificate Management

ssl-init: ## Initialize SSL certificates
	@echo "$(GREEN)Initializing SSL certificates...$(NC)"
	@chmod +x init-ssl.sh
	@bash init-ssl.sh

renew-ssl: ## Renew Let's Encrypt SSL certificates
	@echo "$(GREEN)Renewing SSL certificates...$(NC)"
	@if [ -f .env ]; then \
		. .env; \
		if [ "$$SSL_MODE" = "letsencrypt" ]; then \
			sudo certbot renew; \
			echo "$(GREEN)Copying renewed certificates...$(NC)"; \
			sudo cp /etc/letsencrypt/live/$$DOMAIN/fullchain.pem certs/server.crt; \
			sudo cp /etc/letsencrypt/live/$$DOMAIN/privkey.pem certs/server.key; \
			sudo chown $(shell whoami):$(shell whoami) certs/server.crt certs/server.key; \
			make restart; \
			echo "$(GREEN)✓ SSL certificates renewed and server restarted$(NC)"; \
		else \
			echo "$(YELLOW)SSL_MODE is not set to 'letsencrypt'. Skipping renewal.$(NC)"; \
		fi \
	else \
		echo "$(RED).env file not found. Please run 'make setup' first.$(NC)"; \
	fi

ssl-check: ## Check SSL certificate expiration
	@if [ -f certs/server.crt ]; then \
		echo "$(GREEN)SSL Certificate Information:$(NC)"; \
		openssl x509 -in certs/server.crt -text -noout | grep -E "Subject:|Issuer:|Not Before|Not After"; \
	else \
		echo "$(RED)No SSL certificate found. Run 'make ssl-init' first.$(NC)"; \
	fi

##@ Docker Image Management

build: ## Build FreePBX Docker image
	@echo "$(GREEN)Building FreePBX Docker image...$(NC)"
	@docker-compose build

pull: ## Pull latest Docker images
	@echo "$(GREEN)Pulling latest Docker images...$(NC)"
	@docker-compose pull

##@ Database Management

db-backup: ## Backup MariaDB database
	@echo "$(GREEN)Backing up database...$(NC)"
	@mkdir -p backups
	@docker-compose exec -T mariadb mysqldump -uroot -p$$(grep MYSQL_ROOT_PASSWORD .env | cut -d'=' -f2) --all-databases > backups/db-backup-$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)✓ Database backed up to backups/$(NC)"

db-restore: ## Restore MariaDB database (usage: make db-restore FILE=backup.sql)
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Please specify backup file: make db-restore FILE=backups/backup.sql$(NC)"; \
	else \
		echo "$(YELLOW)Restoring database from $(FILE)...$(NC)"; \
		docker-compose exec -T mariadb mysql -uroot -p$$(grep MYSQL_ROOT_PASSWORD .env | cut -d'=' -f2) < $(FILE); \
		echo "$(GREEN)✓ Database restored$(NC)"; \
	fi

##@ Shell Access

shell-server: ## Open shell in FreePBX container
	@docker-compose exec server /bin/bash

shell-mariadb: ## Open shell in MariaDB container
	@docker-compose exec mariadb /bin/bash

mysql: ## Open MySQL CLI
	@docker-compose exec mariadb mysql -uroot -p$$(grep MYSQL_ROOT_PASSWORD .env | cut -d'=' -f2)

asterisk-cli: ## Open Asterisk CLI
	@docker-compose exec server asterisk -rvvv

##@ Maintenance

clean: ## Remove all containers and volumes (WARNING: destructive)
	@echo "$(RED)WARNING: This will remove all containers and volumes!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [ "$$REPLY" = "y" ] || [ "$$REPLY" = "Y" ]; then \
		echo "$(YELLOW)Removing containers and volumes...$(NC)"; \
		docker-compose down -v; \
		echo "$(GREEN)✓ Cleanup complete$(NC)"; \
	else \
		echo "$(GREEN)Cancelled$(NC)"; \
	fi

clean-logs: ## Clean up old log files
	@echo "$(YELLOW)Cleaning up log files...$(NC)"
	@docker-compose exec server find /var/log/asterisk -name "*.log" -type f -mtime +30 -delete
	@echo "$(GREEN)✓ Old log files removed$(NC)"

prune: ## Remove unused Docker resources
	@echo "$(YELLOW)Removing unused Docker resources...$(NC)"
	@docker system prune -f
	@echo "$(GREEN)✓ Docker cleanup complete$(NC)"

##@ Backup and Restore

backup-full: ## Create full backup (database + certificates + config)
	@echo "$(GREEN)Creating full backup...$(NC)"
	@mkdir -p backups
	@tar -czf backups/freepbx-full-backup-$$(date +%Y%m%d_%H%M%S).tar.gz \
		datadb/ certs/ .env sql/ 2>/dev/null || true
	@echo "$(GREEN)✓ Full backup created in backups/$(NC)"

restore-full: ## Restore full backup (usage: make restore-full FILE=backup.tar.gz)
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Please specify backup file: make restore-full FILE=backups/backup.tar.gz$(NC)"; \
	else \
		echo "$(YELLOW)Restoring from $(FILE)...$(NC)"; \
		tar -xzf $(FILE); \
		echo "$(GREEN)✓ Backup restored. Run 'make restart' to apply changes.$(NC)"; \
	fi

##@ Information

ps: ## Alias for status
	@make status

config: ## Show current docker-compose configuration
	@docker-compose config

info: ## Show system information
	@echo "$(GREEN)System Information:$(NC)"
	@echo "Docker version: $$(docker --version)"
	@echo "Docker Compose version: $$(docker-compose --version)"
	@if [ -f .env ]; then \
		echo "\n$(GREEN)Configuration:$(NC)"; \
		grep -E "^(DOMAIN|SSL_MODE|TZ|FREEPBX_IMAGE)" .env | sed 's/^/  /'; \
	fi
