-- Views

SET search_path = locadora, public;

-- situação, km e agência atuais de cada carro, derivados do histórico
CREATE VIEW vw_carros_status AS
SELECT c.id_carro,
       c.placa,
       m.marca,
       m.nome  AS modelo,
       cat.nome AS categoria,
       cat.valor_diaria,
       c.ano,
       c.combustivel,
       COALESCE(ult.id_agencia_devolucao, c.id_agencia) AS id_agencia_atual,
       ag.nome AS agencia_atual,
       COALESCE(ult.km_devolucao, c.km_inicial)         AS km_atual,
       CASE
           WHEN EXISTS (SELECT 1 FROM aluguel a
                         WHERE a.id_carro = c.id_carro AND a.status = 'EM_ANDAMENTO')
               THEN 'ALUGADO'
           WHEN EXISTS (SELECT 1 FROM manutencao mt
                         WHERE mt.id_carro = c.id_carro AND mt.data_saida IS NULL)
               THEN 'MANUTENCAO'
           ELSE 'DISPONIVEL'
       END AS situacao
FROM carro c
JOIN modelo m     ON m.id_modelo    = c.id_modelo
JOIN categoria cat ON cat.id_categoria = m.id_categoria
LEFT JOIN LATERAL (
    SELECT a.id_agencia_devolucao, a.km_devolucao
    FROM aluguel a
    WHERE a.id_carro = c.id_carro
      AND a.status = 'FINALIZADO'
    ORDER BY a.data_devolucao DESC, a.id_aluguel DESC
    LIMIT 1
) ult ON TRUE
JOIN agencia ag ON ag.id_agencia = COALESCE(ult.id_agencia_devolucao, c.id_agencia);

COMMENT ON VIEW vw_carros_status IS 'Situação, km e agência atuais de cada carro (derivados do histórico)';

-- aluguéis em andamento e dias de atraso em relação a hoje()
CREATE VIEW vw_alugueis_ativos AS
SELECT a.id_aluguel,
       cl.nome AS cliente,
       cl.telefone,
       c.placa,
       m.marca,
       m.nome  AS modelo,
       a.data_retirada,
       a.data_prevista_devolucao,
       GREATEST(hoje() - a.data_prevista_devolucao, 0) AS dias_atraso,
       (hoje() > a.data_prevista_devolucao)            AS atrasado,
       a.valor_previsto
FROM aluguel a
JOIN cliente cl ON cl.id_cliente = a.id_cliente
JOIN carro c    ON c.id_carro    = a.id_carro
JOIN modelo m   ON m.id_modelo   = c.id_modelo
WHERE a.status = 'EM_ANDAMENTO';

COMMENT ON VIEW vw_alugueis_ativos IS 'Aluguéis em andamento; "atrasado" usa a data de referência hoje()';

-- aluguéis finalizados em que o valor pago (pagamentos - estornos) difere do cobrado
CREATE VIEW vw_conciliacao_pagamentos AS
WITH saldo AS (
    SELECT id_aluguel,
           SUM(CASE tipo WHEN 'PAGAMENTO' THEN valor ELSE -valor END) AS total_pago
    FROM pagamento
    GROUP BY id_aluguel
)
SELECT a.id_aluguel,
       cl.nome AS cliente,
       a.valor_final,
       COALESCE(s.total_pago, 0)                  AS total_pago,
       a.valor_final - COALESCE(s.total_pago, 0)  AS diferenca
FROM aluguel a
JOIN cliente cl ON cl.id_cliente = a.id_cliente
LEFT JOIN saldo s ON s.id_aluguel = a.id_aluguel
WHERE a.status = 'FINALIZADO'
  AND a.valor_final <> COALESCE(s.total_pago, 0);

COMMENT ON VIEW vw_conciliacao_pagamentos IS 'Aluguéis finalizados com divergência entre valor cobrado e valor pago';
