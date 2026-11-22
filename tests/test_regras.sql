-- Testes de regras e integridade. Rodar depois de carregar sql/01 a sql/05.
-- No psql: psql -v ON_ERROR_STOP=1 -f tests/test_regras.sql
-- Tudo acontece dentro de uma transação que termina em ROLLBACK.

BEGIN;

SET LOCAL search_path = locadora, public;
SET LOCAL app.data_referencia = '2026-11-12';   -- data fixa: testes reproduzíveis

-- executa o comando e exige que ele falhe com um dos SQLSTATE informados (separados por vírgula)
CREATE FUNCTION pg_temp.esperar_erro(p_nome TEXT, p_sql TEXT, p_sqlstate TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
	v_falhou BOOLEAN := FALSE;
BEGIN
	BEGIN
		EXECUTE p_sql;
	EXCEPTION WHEN OTHERS THEN
		v_falhou := TRUE;
		IF SQLSTATE <> ALL (string_to_array(p_sqlstate, ',')) THEN
			RAISE EXCEPTION 'FALHOU: % (esperava %, recebeu % - %)',
				p_nome, p_sqlstate, SQLSTATE, SQLERRM;
		END IF;
	END;

	IF NOT v_falhou THEN
		RAISE EXCEPTION 'FALHOU: % (nenhum erro foi lançado)', p_nome;
	END IF;

	RAISE NOTICE 'OK: %', p_nome;
END;
$$;

DO $$
BEGIN
	ASSERT (SELECT COUNT(*) FROM agencia)     = 3,   'esperava 3 agências';
	ASSERT (SELECT COUNT(*) FROM funcionario) = 6,   'esperava 6 funcionários';
	ASSERT (SELECT COUNT(*) FROM carro)       = 20,  'esperava 20 carros';
	ASSERT (SELECT COUNT(*) FROM cliente)     = 40,  'esperava 40 clientes';
	ASSERT (SELECT COUNT(*) FROM aluguel)     = 224, 'esperava 224 aluguéis (220 histórico + 4 atuais)';
	ASSERT (SELECT COUNT(*) FROM pagamento)   = 221, 'esperava 221 lançamentos de pagamento';
	ASSERT (SELECT COUNT(*) FROM manutencao)  = 41,  'esperava 41 manutenções';
	RAISE NOTICE 'OK: volumes da carga de dados';
END
$$;

DO $$
BEGIN
	ASSERT calcular_valor(100.00, DATE '2026-01-01', DATE '2026-01-03', DATE '2026-01-05') = 440.00,
		'cálculo com atraso';
	ASSERT calcular_valor(100.00, DATE '2026-01-01', DATE '2026-01-03', DATE '2026-01-03') = 200.00,
		'cálculo sem atraso';
	ASSERT calcular_valor(100.00, DATE '2026-01-01', DATE '2026-01-03', DATE '2026-01-01') = 100.00,
		'mínimo de 1 diária';

	ASSERT cpf_valido('52998224725'),      'CPF válido deveria passar';
	ASSERT NOT cpf_valido('52998224726'),  'dígito verificador errado deveria falhar';
	ASSERT NOT cpf_valido('11111111111'),  'sequência repetida deveria falhar';
	ASSERT NOT cpf_valido('1234'),         'tamanho errado deveria falhar';

	ASSERT hoje() = DATE '2026-11-12', 'hoje() deveria respeitar app.data_referencia';
	RAISE NOTICE 'OK: calcular_valor, cpf_valido e hoje';
END
$$;

DO $$
BEGIN
	ASSERT (SELECT situacao FROM vw_carros_status WHERE placa = 'ABC1D23') = 'ALUGADO',
		'ABC1D23 tem aluguel em andamento';
	ASSERT (SELECT situacao FROM vw_carros_status WHERE placa = 'RJD1K23') = 'MANUTENCAO',
		'RJD1K23 está na oficina';
	ASSERT (SELECT situacao FROM vw_carros_status WHERE placa = 'RIO2A45') = 'DISPONIVEL',
		'RIO2A45 está livre';

	ASSERT (SELECT agencia_atual FROM vw_carros_status WHERE placa = 'DDE8A90') = 'São Paulo - Bela Vista',
		'DDE8A90 deveria estar em São Paulo após a devolução';

	ASSERT (SELECT COUNT(*) FROM vw_carros_status WHERE situacao = 'ALUGADO')     = 3,  '3 alugados';
	ASSERT (SELECT COUNT(*) FROM vw_carros_status WHERE situacao = 'MANUTENCAO')  = 1,  '1 em manutenção';
	ASSERT (SELECT COUNT(*) FROM vw_carros_status WHERE situacao = 'DISPONIVEL')  = 16, '16 disponíveis';

	ASSERT (SELECT COUNT(*) FROM vw_alugueis_ativos) = 3, '3 aluguéis ativos';
	ASSERT (SELECT COUNT(*) FROM vw_alugueis_ativos WHERE atrasado) = 2,
		'2 atrasados em 12/11/2026';
	RAISE NOTICE 'OK: views de estado derivado';
END
$$;

DO $$
BEGIN
	PERFORM pg_temp.esperar_erro('placa inválida é rejeitada (CHECK)',
		$q$INSERT INTO carro (placa, id_modelo, id_agencia, ano, cor, combustivel)
		   SELECT 'ABC-123', (SELECT MIN(id_modelo) FROM modelo),
		          (SELECT MIN(id_agencia) FROM agencia), 2020, 'Preto', 'FLEX'::combustivel_tipo$q$,
		'23514');

	PERFORM pg_temp.esperar_erro('CPF com dígito verificador errado é rejeitado (CHECK)',
		$q$UPDATE cliente SET cpf = '12345678900' WHERE nome = 'André'$q$,
		'23514');

	PERFORM pg_temp.esperar_erro('CPF duplicado é rejeitado (UNIQUE)',
		$q$UPDATE cliente SET cpf = (SELECT cpf FROM cliente WHERE nome = 'André')
		   WHERE nome = 'Bruna'$q$,
		'23505');

	PERFORM pg_temp.esperar_erro('aluguéis sobrepostos do mesmo carro são rejeitados (EXCLUDE)',
		$q$INSERT INTO aluguel (id_cliente, id_carro, id_funcionario, id_agencia_retirada,
		                        id_agencia_devolucao, data_retirada, data_prevista_devolucao,
		                        data_devolucao, km_retirada, km_devolucao, valor_diaria,
		                        valor_previsto, valor_final, status)
		   SELECT id_cliente, id_carro, id_funcionario, id_agencia_retirada,
		          id_agencia_devolucao, data_retirada, data_prevista_devolucao,
		          data_devolucao, km_retirada, km_devolucao, valor_diaria,
		          valor_previsto, valor_final, status
		   FROM aluguel WHERE id_aluguel = 1$q$,
		'23P01');

	PERFORM pg_temp.esperar_erro('FINALIZADO sem dados de devolução é rejeitado (CHECK de estado)',
		$q$UPDATE aluguel SET status = 'FINALIZADO' WHERE status = 'EM_ANDAMENTO'$q$,
		'23514');

	-- o código do erro de RESTRICT varia entre versões do PostgreSQL (23001 ou 23503)
	PERFORM pg_temp.esperar_erro('não se apaga carro que já foi alugado (FK RESTRICT)',
		$q$DELETE FROM carro WHERE placa = 'ABC1D23'$q$,
		'23001,23503');

	PERFORM pg_temp.esperar_erro('pagamento de valor negativo é rejeitado (CHECK)',
		$q$INSERT INTO pagamento (id_aluguel, forma, valor, pago_em)
		   VALUES (1, 'PIX', -10, now())$q$,
		'23514');
END
$$;

DO $$
BEGIN
	PERFORM pg_temp.esperar_erro('carro já alugado -> LC001',
		$q$SELECT abrir_aluguel(
		       (SELECT id_cliente FROM cliente WHERE nome = 'Elisa'),
		       (SELECT id_carro FROM carro WHERE placa = 'ABC1D23'),
		       (SELECT MIN(id_funcionario) FROM funcionario),
		       DATE '2026-11-12', DATE '2026-11-14')$q$,
		'LC001');

	PERFORM pg_temp.esperar_erro('carro em manutenção -> LC001',
		$q$SELECT abrir_aluguel(
		       (SELECT id_cliente FROM cliente WHERE nome = 'Elisa'),
		       (SELECT id_carro FROM carro WHERE placa = 'RJD1K23'),
		       (SELECT MIN(id_funcionario) FROM funcionario),
		       DATE '2026-11-12', DATE '2026-11-14')$q$,
		'LC001');

	PERFORM pg_temp.esperar_erro('CNH categoria A não aluga carro -> LC002',
		$q$SELECT abrir_aluguel(
		       (SELECT id_cliente FROM cliente WHERE nome = 'Mariana Cardoso'),
		       (SELECT id_carro FROM carro WHERE placa = 'RIO2A45'),
		       (SELECT MIN(id_funcionario) FROM funcionario),
		       DATE '2026-11-12', DATE '2026-11-14')$q$,
		'LC002');

	PERFORM pg_temp.esperar_erro('CNH vencida -> LC003',
		$q$SELECT abrir_aluguel(
		       (SELECT id_cliente FROM cliente WHERE nome = 'Henrique Almeida'),
		       (SELECT id_carro FROM carro WHERE placa = 'RIO2A45'),
		       (SELECT MIN(id_funcionario) FROM funcionario),
		       DATE '2026-11-12', DATE '2026-11-14')$q$,
		'LC003');

	PERFORM pg_temp.esperar_erro('devolução prevista igual à retirada -> LC005',
		$q$SELECT abrir_aluguel(
		       (SELECT id_cliente FROM cliente WHERE nome = 'Elisa'),
		       (SELECT id_carro FROM carro WHERE placa = 'RIO2A45'),
		       (SELECT MIN(id_funcionario) FROM funcionario),
		       DATE '2026-11-12', DATE '2026-11-12')$q$,
		'LC005');

	PERFORM pg_temp.esperar_erro('funcionário de outra agência é rejeitado (FK composta)',
		$q$SELECT abrir_aluguel(
		       (SELECT id_cliente FROM cliente WHERE nome = 'Elisa'),
		       (SELECT id_carro FROM carro WHERE placa = 'RIO2A45'),
		       (SELECT f.id_funcionario FROM funcionario f JOIN agencia a USING (id_agencia)
		         WHERE a.nome = 'Belo Horizonte - Savassi' AND f.cargo = 'ATENDENTE'),
		       DATE '2026-11-12', DATE '2026-11-14')$q$,
		'23503');

	PERFORM pg_temp.esperar_erro('cancelar aluguel inexistente -> LC006',
		$q$SELECT cancelar_aluguel(999999)$q$,
		'LC006');
END
$$;

DO $$
BEGIN
	BEGIN
		-- o UPDATE é desfeito quando a exceção é capturada
		UPDATE cliente SET data_nascimento = DATE '2015-01-01' WHERE nome = 'Elisa';
		PERFORM abrir_aluguel(
			(SELECT id_cliente FROM cliente WHERE nome = 'Elisa'),
			(SELECT id_carro FROM carro WHERE placa = 'RIO2A45'),
			(SELECT f.id_funcionario FROM funcionario f JOIN agencia a USING (id_agencia)
			  WHERE a.nome = 'Rio - Centro' AND f.cargo = 'ATENDENTE'),
			DATE '2026-11-12', DATE '2026-11-14');
		RAISE EXCEPTION 'FALHOU: menor de idade conseguiu alugar';
	EXCEPTION WHEN SQLSTATE 'LC004' THEN
		RAISE NOTICE 'OK: menor de 18 anos -> LC004';
	END;
END
$$;

DO $$
BEGIN
	-- divergências propositais do seed
	ASSERT (SELECT COUNT(*) FROM vw_conciliacao_pagamentos) = 2, 'esperava 2 divergências';
	ASSERT (SELECT array_agg(id_aluguel ORDER BY id_aluguel) FROM vw_conciliacao_pagamentos) = ARRAY[10, 20],
		'divergências nos aluguéis 10 e 20';
	ASSERT (SELECT diferenca FROM vw_conciliacao_pagamentos WHERE id_aluguel = 10) = 10.00,
		'aluguel 10: faltam R$ 10,00';
	ASSERT (SELECT diferenca = valor_final FROM vw_conciliacao_pagamentos WHERE id_aluguel = 20),
		'aluguel 20: nada foi pago';
	RAISE NOTICE 'OK: conciliação de pagamentos (inclui o estorno do aluguel 30)';

	ASSERT (SELECT COUNT(*) FROM dw.fato_aluguel) = (SELECT COUNT(*) FROM aluguel WHERE status = 'FINALIZADO'),
		'fato deveria ter 1 linha por aluguel finalizado';
	ASSERT (SELECT SUM(valor_final) FROM dw.fato_aluguel) = (SELECT SUM(valor_final) FROM aluguel WHERE status = 'FINALIZADO'),
		'faturamento do DW deveria bater com o OLTP';
	ASSERT (SELECT COUNT(*) FROM dw.dim_data) = 1095, 'calendário de 3 anos';
	ASSERT NOT EXISTS (
		SELECT 1 FROM dw.fato_aluguel f
		LEFT JOIN dw.dim_data d1 ON d1.sk_data = f.sk_data_retirada
		LEFT JOIN dw.dim_data d2 ON d2.sk_data = f.sk_data_devolucao
		WHERE d1.sk_data IS NULL OR d2.sk_data IS NULL
	), 'toda data da fato precisa existir em dim_data';
	ASSERT NOT EXISTS (
		SELECT 1
		FROM pg_attribute a
		JOIN pg_class c     ON c.oid = a.attrelid
		JOIN pg_namespace n ON n.oid = c.relnamespace
		WHERE n.nspname = 'dw' AND a.attnum > 0 AND NOT a.attisdropped
		  AND a.attname IN ('cpf', 'cnh', 'email', 'telefone')
	), 'dw não deve conter CPF, CNH, e-mail nem telefone';
	RAISE NOTICE 'OK: DW consistente com o OLTP e sem dados pessoais sensíveis';
END
$$;

DO $$
DECLARE
	v_cliente  INT;
	v_creta    INT;
	v_polo     INT;
	v_func_bh  INT;
	v_func_rio INT;
	v_agencia_rio INT;
	v_km_antes INT;
	v_id       INT;
	v_id2      INT;
	v_total    NUMERIC;
BEGIN
	SELECT id_cliente INTO v_cliente FROM cliente WHERE nome = 'Elisa';
	SELECT id_carro INTO v_creta FROM carro WHERE placa = 'BHA7G90';   -- SUV, diária R$ 250
	SELECT id_carro INTO v_polo  FROM carro WHERE placa = 'RIO2A45';
	SELECT id_agencia INTO v_agencia_rio FROM agencia WHERE nome = 'Rio - Centro';

	SELECT f.id_funcionario INTO v_func_bh
	  FROM funcionario f JOIN agencia a USING (id_agencia)
	 WHERE a.nome = 'Belo Horizonte - Savassi' AND f.cargo = 'ATENDENTE';
	SELECT f.id_funcionario INTO v_func_rio
	  FROM funcionario f JOIN agencia a USING (id_agencia)
	 WHERE a.nome = 'Rio - Centro' AND f.cargo = 'ATENDENTE';

	SELECT km_atual INTO v_km_antes FROM vw_carros_status WHERE id_carro = v_creta;
	v_id := abrir_aluguel(v_cliente, v_creta, v_func_bh, DATE '2026-11-10', DATE '2026-11-12');

	ASSERT (SELECT situacao FROM vw_carros_status WHERE id_carro = v_creta) = 'ALUGADO',
		'carro deveria ficar ALUGADO após abrir_aluguel';
	ASSERT (SELECT valor_previsto FROM aluguel WHERE id_aluguel = v_id) = 500.00,
		'valor previsto: 2 diárias de R$ 250';
	ASSERT (SELECT km_retirada FROM aluguel WHERE id_aluguel = v_id) = v_km_antes,
		'km de retirada = km atual do carro';

	v_total := finalizar_aluguel(v_id, v_km_antes + 300, v_agencia_rio, DATE '2026-11-13');
	ASSERT v_total = 800.00, 'valor final: 3 x 250 + 1 x 250 x 20% = 800';

	ASSERT (SELECT situacao FROM vw_carros_status WHERE id_carro = v_creta) = 'DISPONIVEL',
		'carro deveria voltar a DISPONIVEL';
	ASSERT (SELECT agencia_atual FROM vw_carros_status WHERE id_carro = v_creta) = 'Rio - Centro',
		'carro deveria estar na agência de devolução';
	ASSERT (SELECT km_atual FROM vw_carros_status WHERE id_carro = v_creta) = v_km_antes + 300,
		'km atual = km de devolução';
	RAISE NOTICE 'OK: fluxo abrir -> finalizar (valor, situação, agência e km)';

	PERFORM pg_temp.esperar_erro('finalizar aluguel já finalizado -> LC006',
		format('SELECT finalizar_aluguel(%s, 999999, 1, DATE ''2026-11-14'')', v_id),
		'LC006');

	v_id2 := abrir_aluguel(v_cliente, v_polo, v_func_rio, DATE '2026-11-12', DATE '2026-11-14');
	PERFORM pg_temp.esperar_erro('km de devolução menor que o de retirada -> LC005',
		format('SELECT finalizar_aluguel(%s, 0, 1, DATE ''2026-11-13'')', v_id2),
		'LC005');

	PERFORM cancelar_aluguel(v_id2);
	ASSERT (SELECT situacao FROM vw_carros_status WHERE id_carro = v_polo) = 'DISPONIVEL',
		'carro deveria voltar a DISPONIVEL após cancelar';
	RAISE NOTICE 'OK: cancelamento libera o carro';
END
$$;

DO $$
BEGIN
	-- o DW é um snapshot: só enxerga o aluguel novo depois de dw.atualizar()
	ASSERT (SELECT COUNT(*) FROM dw.fato_aluguel) < (SELECT COUNT(*) FROM aluguel WHERE status = 'FINALIZADO'),
		'antes de atualizar, o DW está defasado';
	PERFORM dw.atualizar();
	ASSERT (SELECT COUNT(*) FROM dw.fato_aluguel) = (SELECT COUNT(*) FROM aluguel WHERE status = 'FINALIZADO'),
		'depois de dw.atualizar(), o DW alcança o OLTP';
	RAISE NOTICE 'OK: dw.atualizar() sincroniza a camada analítica';
END
$$;

DO $$ BEGIN RAISE NOTICE '=== TODOS OS TESTES PASSARAM ==='; END $$;

ROLLBACK;

-- só chega aqui se nenhum teste falhou; mostra o resultado em clientes gráficos
SELECT 'todos os testes passaram' AS resultado;
