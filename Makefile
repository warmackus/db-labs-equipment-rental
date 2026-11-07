DB_NAME     = equipment_rental
DB_USER     = warmack
CONTAINER   = equipment-rental-db
DB_SERVICE  = db

.PHONY: help up down reset psql logs sync schema test

help:
	@echo "make up | down | reset | psql | logs | sync | schema | test"

up:
	docker compose up -d

down:
	docker compose down

reset:
	docker compose down -v
	docker compose up -d

psql:
	docker exec -it $(CONTAINER) psql -U $(DB_USER) -d $(DB_NAME)

logs:
	docker compose logs -f $(DB_SERVICE)

sync:
	cp lab_1/schema.sql docker/init/01_schema.sql

schema:
	docker exec -i $(CONTAINER) psql -U $(DB_USER) -d $(DB_NAME) < lab_1/schema.sql

test:
	docker exec -it $(CONTAINER) psql -U $(DB_USER) -d $(DB_NAME) -c "\dt"