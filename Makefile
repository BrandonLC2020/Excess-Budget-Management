# Excess Budget — backend developer commands.
# Usage: `make <target>` from the project root.

COMPOSE      ?= docker compose -f backend/docker-compose.yml
WEB          ?= web
DB           ?= db
HEALTH_URL   ?= http://localhost:8000/api/v1/health

# Default target: show available commands.
.DEFAULT_GOAL := help

.PHONY: help
help:  ## Show this help.
	@awk 'BEGIN {FS = ":.*##"; printf "Targets:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# --- Stack lifecycle ------------------------------------------------------

.PHONY: up
up:  ## Start the stack (db + web) detached. Builds if needed.
	$(COMPOSE) up -d --build
	@echo "→ http://localhost:8000/api/v1/health"

.PHONY: up-fg
up-fg:  ## Start the stack in the foreground (logs stream live).
	$(COMPOSE) up --build

.PHONY: down
down:  ## Stop and remove containers (preserves db volume).
	$(COMPOSE) down

.PHONY: restart
restart:  ## Restart the web service only.
	$(COMPOSE) restart $(WEB)

.PHONY: build
build:  ## Rebuild the web image without starting.
	$(COMPOSE) build $(WEB)

.PHONY: ps
ps:  ## Show container status.
	$(COMPOSE) ps

.PHONY: logs
logs:  ## Tail web logs (Ctrl-C to detach).
	$(COMPOSE) logs -f $(WEB)

.PHONY: logs-db
logs-db:  ## Tail Postgres logs.
	$(COMPOSE) logs -f $(DB)

# --- Django ---------------------------------------------------------------

.PHONY: migrate
migrate:  ## Apply migrations against the running stack.
	$(COMPOSE) exec $(WEB) uv run python manage.py migrate

.PHONY: makemigrations
makemigrations:  ## Generate new migrations (pass APP=<name> to scope).
	$(COMPOSE) exec $(WEB) uv run python manage.py makemigrations $(APP)

.PHONY: superuser
superuser:  ## Create a Django superuser interactively.
	$(COMPOSE) exec $(WEB) uv run python manage.py createsuperuser

.PHONY: shell
shell:  ## Open a Django shell inside the web container.
	$(COMPOSE) exec $(WEB) uv run python manage.py shell

.PHONY: bash
bash:  ## Open a bash shell inside the web container.
	$(COMPOSE) exec $(WEB) bash

# --- Database -------------------------------------------------------------

.PHONY: psql
psql:  ## Open a psql session against the dockerized Postgres.
	$(COMPOSE) exec $(DB) psql -U postgres -d excess

# --- Quality gates --------------------------------------------------------

.PHONY: test
test:  ## Run pytest inside the web container (pass ARGS=... for extras).
	$(COMPOSE) exec $(WEB) uv run pytest $(ARGS)

.PHONY: lint
lint:  ## Run ruff check (pass FIX=1 to auto-fix).
	$(COMPOSE) exec $(WEB) uv run ruff check $(if $(FIX),--fix,) .

.PHONY: health
health:  ## Hit the /health endpoint from the host.
	@curl -fsS $(HEALTH_URL) && echo

# --- Destructive ----------------------------------------------------------

.PHONY: clean
clean:  ## Stop containers AND delete the db volume. Wipes local data.
	@printf "This will DELETE the Postgres volume. Type 'yes' to continue: " \
	  && read confirm && [ "$$confirm" = "yes" ] \
	  && $(COMPOSE) down -v \
	  || echo "Aborted."
