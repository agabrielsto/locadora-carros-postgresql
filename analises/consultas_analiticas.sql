-- Consultas de exemplo. A data de referência é fixada para o resultado ser reproduzível.

SET search_path = locadora, public;
SET app.data_referencia = '2026-11-12';

-- 1. frota por situação
SELECT situacao, COUNT(*) AS qtd_carros
FROM locadora.vw_carros_status
GROUP BY situacao
ORDER BY situacao;

-- 2. aluguéis atrasados
SELECT id_aluguel, cliente, telefone, placa, modelo,
       data_prevista_devolucao, dias_atraso
FROM locadora.vw_alugueis_ativos
WHERE atrasado
ORDER BY dias_atraso DESC;

-- 3. divergências de pagamento
SELECT id_aluguel, cliente, valor_final, total_pago, diferenca
FROM locadora.vw_conciliacao_pagamentos
ORDER BY id_aluguel;

-- 4. lucro por carro (receita - manutenção)
WITH receita AS (
	SELECT id_carro, SUM(valor_final) AS receita
	FROM locadora.aluguel
	WHERE status = 'FINALIZADO'
	GROUP BY id_carro
),
custo AS (
	SELECT id_carro, SUM(custo) AS custo_manutencao
	FROM locadora.manutencao
	GROUP BY id_carro
)
SELECT c.placa, c.marca, c.modelo,
       COALESCE(r.receita, 0)                                    AS receita,
       COALESCE(m.custo_manutencao, 0)                           AS custo_manutencao,
       COALESCE(r.receita, 0) - COALESCE(m.custo_manutencao, 0)  AS lucro
FROM locadora.vw_carros_status c
LEFT JOIN receita r ON r.id_carro = c.id_carro
LEFT JOIN custo m   ON m.id_carro = c.id_carro
ORDER BY lucro DESC
LIMIT 10;

-- 5. faturamento mensal e variação sobre o mês anterior
WITH mensal AS (
	SELECT d.ano, d.mes,
	       COUNT(*)            AS qtd_alugueis,
	       SUM(f.valor_final)  AS faturamento
	FROM dw.fato_aluguel f
	JOIN dw.dim_data d ON d.sk_data = f.sk_data_devolucao
	GROUP BY d.ano, d.mes
)
SELECT ano, mes, qtd_alugueis, faturamento,
       LAG(faturamento) OVER (ORDER BY ano, mes) AS mes_anterior,
       ROUND(100.0 * (faturamento - LAG(faturamento) OVER (ORDER BY ano, mes))
             / NULLIF(LAG(faturamento) OVER (ORDER BY ano, mes), 0), 1) AS variacao_pct
FROM mensal
ORDER BY ano, mes;

-- 6. três carros que mais faturam por agência
SELECT agencia, placa, modelo, faturamento, posicao
FROM (
	SELECT ag.nome AS agencia,
	       ca.placa,
	       ca.modelo,
	       SUM(f.valor_final) AS faturamento,
	       RANK() OVER (PARTITION BY ag.sk_agencia ORDER BY SUM(f.valor_final) DESC) AS posicao
	FROM dw.fato_aluguel f
	JOIN dw.dim_agencia ag ON ag.sk_agencia = f.sk_agencia_retirada
	JOIN dw.dim_carro ca   ON ca.sk_carro   = f.sk_carro
	GROUP BY ag.sk_agencia, ag.nome, ca.sk_carro, ca.placa, ca.modelo
) ranking
WHERE posicao <= 3
ORDER BY agencia, posicao;

-- 7. fim de semana x dia útil
SELECT CASE WHEN d.fim_de_semana THEN 'Fim de semana' ELSE 'Dia útil' END AS retirada_em,
       COUNT(*)                                       AS qtd_alugueis,
       ROUND(AVG(f.valor_final), 2)                   AS ticket_medio,
       ROUND(SUM(f.valor_final) / SUM(f.qtd_dias), 2) AS receita_por_diaria
FROM dw.fato_aluguel f
JOIN dw.dim_data d ON d.sk_data = f.sk_data_retirada
GROUP BY d.fim_de_semana
ORDER BY d.fim_de_semana;

-- 8. ocupação em 2026 (dias alugados / 365)
SELECT ca.placa, ca.modelo,
       COUNT(*)                          AS dias_alugados,
       ROUND(100.0 * COUNT(*) / 365, 1)  AS ocupacao_pct
FROM dw.fato_aluguel f
JOIN dw.dim_data d  ON d.data >= f.data_retirada
                   AND d.data <  f.data_devolucao
                   AND d.ano = 2026
JOIN dw.dim_carro ca ON ca.sk_carro = f.sk_carro
GROUP BY ca.placa, ca.modelo
ORDER BY dias_alugados DESC, ca.placa
LIMIT 5;

-- 9. clientes por quartil de gasto
WITH gasto AS (
	SELECT cl.sk_cliente, cl.nome, SUM(f.valor_final) AS total_gasto
	FROM dw.fato_aluguel f
	JOIN dw.dim_cliente cl ON cl.sk_cliente = f.sk_cliente
	GROUP BY cl.sk_cliente, cl.nome
),
segmentado AS (
	SELECT g.*, NTILE(4) OVER (ORDER BY g.total_gasto DESC) AS quartil
	FROM gasto g
)
SELECT quartil,
       COUNT(*)                    AS qtd_clientes,
       ROUND(AVG(total_gasto), 2)  AS gasto_medio,
       SUM(total_gasto)            AS gasto_total
FROM segmentado
GROUP BY quartil
ORDER BY quartil;
