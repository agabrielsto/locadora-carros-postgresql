.PHONY: up down reset psql test analises dw export

DB = docker compose exec -T db psql -U postgres -d locadora -v ON_ERROR_STOP=1

up:
	docker compose up -d --wait

down:
	docker compose down

reset:
	docker compose down -v
	docker compose up -d --wait

psql:
	docker compose exec db psql -U postgres -d locadora

test:
	$(DB) -f /tests/test_regras.sql

analises:
	$(DB) -f /analises/consultas_analiticas.sql

dw:
	$(DB) -c "SELECT dw.atualizar();"

export:
	mkdir -p exports
	for t in dim_data dim_cliente dim_carro dim_agencia fato_aluguel; do \
		docker compose exec -T db psql -U postgres -d locadora \
			-c "\copy (SELECT * FROM dw.$$t) TO STDOUT WITH CSV HEADER" > exports/$$t.csv; \
	done
	@echo "CSVs gerados em ./exports"
