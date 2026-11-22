-- Camada analítica: 1 fato e 4 dimensões em materialized views.
-- Recarregar com SELECT dw.atualizar(). Não contém CPF, CNH, e-mail nem telefone.

CREATE SCHEMA IF NOT EXISTS dw;

-- calendário de 2025 a 2027; sk_data no formato AAAAMMDD
CREATE MATERIALIZED VIEW dw.dim_data AS
WITH dias AS (
	SELECT (DATE '2025-01-01' + g)::date AS data
	FROM generate_series(0, 1094) AS g
)
SELECT TO_CHAR(data, 'YYYYMMDD')::INT                     AS sk_data,
       data,
       EXTRACT(YEAR FROM data)::INT                       AS ano,
       EXTRACT(QUARTER FROM data)::INT                    AS trimestre,
       EXTRACT(MONTH FROM data)::INT                      AS mes,
       (ARRAY['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
              'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro']
       )[EXTRACT(MONTH FROM data)::INT]                   AS nome_mes,
       EXTRACT(ISODOW FROM data)::INT                     AS dia_semana,
       (ARRAY['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo']
       )[EXTRACT(ISODOW FROM data)::INT]                  AS nome_dia_semana,
       EXTRACT(ISODOW FROM data) IN (6, 7)                AS fim_de_semana
FROM dias;

CREATE MATERIALIZED VIEW dw.dim_cliente AS
SELECT id_cliente AS sk_cliente,
       nome,
       cnh_categoria,
       (EXTRACT(YEAR FROM data_nascimento)::INT / 10) * 10 AS decada_nascimento
FROM locadora.cliente;

CREATE MATERIALIZED VIEW dw.dim_carro AS
SELECT c.id_carro AS sk_carro,
       c.placa,
       m.marca,
       m.nome     AS modelo,
       cat.nome   AS categoria,
       c.ano,
       c.combustivel::TEXT AS combustivel
FROM locadora.carro c
JOIN locadora.modelo m      ON m.id_modelo      = c.id_modelo
JOIN locadora.categoria cat ON cat.id_categoria = m.id_categoria;

CREATE MATERIALIZED VIEW dw.dim_agencia AS
SELECT id_agencia AS sk_agencia,
       nome,
       cidade,
       uf
FROM locadora.agencia;

-- uma linha por aluguel finalizado
CREATE MATERIALIZED VIEW dw.fato_aluguel AS
SELECT a.id_aluguel,  -- dimensão degenerada
       TO_CHAR(a.data_retirada,  'YYYYMMDD')::INT AS sk_data_retirada,
       TO_CHAR(a.data_devolucao, 'YYYYMMDD')::INT AS sk_data_devolucao,
       a.data_retirada,
       a.data_devolucao,
       a.id_cliente             AS sk_cliente,
       a.id_carro               AS sk_carro,
       a.id_agencia_retirada    AS sk_agencia_retirada,
       a.id_agencia_devolucao   AS sk_agencia_devolucao,
       GREATEST(a.data_devolucao - a.data_retirada, 1)           AS qtd_dias,
       GREATEST(a.data_devolucao - a.data_prevista_devolucao, 0) AS dias_atraso,
       a.km_devolucao - a.km_retirada                            AS km_rodados,
       a.valor_diaria,
       a.valor_final
FROM locadora.aluguel a
WHERE a.status = 'FINALIZADO';

CREATE UNIQUE INDEX ux_dim_data_sk       ON dw.dim_data (sk_data);
CREATE INDEX        idx_dim_data_data    ON dw.dim_data (data);
CREATE UNIQUE INDEX ux_dim_cliente_sk    ON dw.dim_cliente (sk_cliente);
CREATE UNIQUE INDEX ux_dim_carro_sk      ON dw.dim_carro (sk_carro);
CREATE UNIQUE INDEX ux_dim_agencia_sk    ON dw.dim_agencia (sk_agencia);
CREATE UNIQUE INDEX ux_fato_aluguel_id   ON dw.fato_aluguel (id_aluguel);
CREATE INDEX idx_fato_data_devolucao     ON dw.fato_aluguel (sk_data_devolucao);
CREATE INDEX idx_fato_carro              ON dw.fato_aluguel (sk_carro);
CREATE INDEX idx_fato_cliente            ON dw.fato_aluguel (sk_cliente);

CREATE FUNCTION dw.atualizar() RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
	REFRESH MATERIALIZED VIEW dw.dim_data;
	REFRESH MATERIALIZED VIEW dw.dim_cliente;
	REFRESH MATERIALIZED VIEW dw.dim_carro;
	REFRESH MATERIALIZED VIEW dw.dim_agencia;
	REFRESH MATERIALIZED VIEW dw.fato_aluguel;
END;
$$;

COMMENT ON SCHEMA dw IS 'Camada analítica: star schema derivado do schema locadora (sem dados pessoais sensíveis)';
COMMENT ON MATERIALIZED VIEW dw.fato_aluguel IS 'Grão: 1 linha = 1 aluguel finalizado. Atualizar com SELECT dw.atualizar()';
COMMENT ON FUNCTION dw.atualizar() IS 'Recalcula as dimensões e a fato (carga completa)';
