-- Funções de negócio
-- Erros próprios (SQLSTATE): LC001 carro indisponível, LC002 CNH não permite carro,
-- LC003 CNH vence antes da devolução, LC004 menor de 18 anos, LC005 datas ou km inválidos,
-- LC006 registro não encontrado ou em estado inválido

SET search_path = locadora, public;

-- data de referência; para fixar: SET app.data_referencia = 'AAAA-MM-DD'
CREATE FUNCTION hoje() RETURNS DATE
LANGUAGE sql STABLE
AS $$
	SELECT COALESCE(
		NULLIF(current_setting('app.data_referencia', true), '')::date,
		(now() AT TIME ZONE 'America/Sao_Paulo')::date
	);
$$;

-- diárias reais (mínimo 1) + 20% por dia de atraso
CREATE FUNCTION calcular_valor(
	p_valor_diaria NUMERIC,
	p_data_retirada DATE,
	p_data_prevista DATE,
	p_data_devolucao DATE
) RETURNS NUMERIC
LANGUAGE sql IMMUTABLE
AS $$
	SELECT ROUND(
		GREATEST(p_data_devolucao - p_data_retirada, 1) * p_valor_diaria
		+ GREATEST(p_data_devolucao - p_data_prevista, 0) * p_valor_diaria * 0.20,
		2
	);
$$;

CREATE FUNCTION abrir_aluguel(
	p_id_cliente              INT,
	p_id_carro                INT,
	p_id_funcionario          INT,
	p_data_retirada           DATE,
	p_data_prevista_devolucao DATE
) RETURNS INT
LANGUAGE plpgsql
SET search_path = locadora, pg_temp
AS $$
DECLARE
	v_cliente cliente%ROWTYPE;
	v_carro   RECORD;
	v_id      INT;
BEGIN
	IF p_data_prevista_devolucao <= p_data_retirada THEN
		RAISE EXCEPTION 'A devolução prevista deve ser posterior à retirada'
			USING ERRCODE = 'LC005';
	END IF;

	SELECT * INTO v_cliente FROM cliente WHERE id_cliente = p_id_cliente;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Cliente % não encontrado', p_id_cliente USING ERRCODE = 'LC006';
	END IF;

	IF v_cliente.cnh_categoria NOT IN ('B', 'AB', 'C', 'D', 'E') THEN
		RAISE EXCEPTION 'CNH categoria % não permite dirigir carro', v_cliente.cnh_categoria
			USING ERRCODE = 'LC002';
	END IF;

	IF v_cliente.cnh_validade < p_data_prevista_devolucao THEN
		RAISE EXCEPTION 'CNH vence em %, antes da devolução prevista', v_cliente.cnh_validade
			USING ERRCODE = 'LC003';
	END IF;

	IF EXTRACT(YEAR FROM age(p_data_retirada, v_cliente.data_nascimento)) < 18 THEN
		RAISE EXCEPTION 'Cliente menor de 18 anos não pode alugar carro'
			USING ERRCODE = 'LC004';
	END IF;

	-- trava o carro para duas sessões não abrirem aluguel ao mesmo tempo
	PERFORM 1 FROM carro WHERE id_carro = p_id_carro FOR UPDATE;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Carro % não encontrado', p_id_carro USING ERRCODE = 'LC006';
	END IF;

	SELECT situacao, km_atual, id_agencia_atual, valor_diaria
	  INTO v_carro
	  FROM vw_carros_status
	 WHERE id_carro = p_id_carro;

	IF v_carro.situacao <> 'DISPONIVEL' THEN
		RAISE EXCEPTION 'Carro % indisponível (situação: %)', p_id_carro, v_carro.situacao
			USING ERRCODE = 'LC001';
	END IF;

	INSERT INTO aluguel (
		id_cliente, id_carro, id_funcionario, id_agencia_retirada,
		data_retirada, data_prevista_devolucao, km_retirada,
		valor_diaria, valor_previsto
	) VALUES (
		p_id_cliente, p_id_carro, p_id_funcionario, v_carro.id_agencia_atual,
		p_data_retirada, p_data_prevista_devolucao, v_carro.km_atual,
		v_carro.valor_diaria,
		calcular_valor(v_carro.valor_diaria, p_data_retirada,
		               p_data_prevista_devolucao, p_data_prevista_devolucao)
	)
	RETURNING id_aluguel INTO v_id;

	RETURN v_id;
END;
$$;

CREATE FUNCTION finalizar_aluguel(
	p_id_aluguel           INT,
	p_km_devolucao         INT,
	p_id_agencia_devolucao INT,
	p_data_devolucao       DATE
) RETURNS NUMERIC
LANGUAGE plpgsql
SET search_path = locadora, pg_temp
AS $$
DECLARE
	v_aluguel aluguel%ROWTYPE;
	v_total   NUMERIC(10,2);
BEGIN
	SELECT * INTO v_aluguel FROM aluguel WHERE id_aluguel = p_id_aluguel FOR UPDATE;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Aluguel % não encontrado', p_id_aluguel USING ERRCODE = 'LC006';
	END IF;

	IF v_aluguel.status <> 'EM_ANDAMENTO' THEN
		RAISE EXCEPTION 'Aluguel % não está em andamento (status: %)', p_id_aluguel, v_aluguel.status
			USING ERRCODE = 'LC006';
	END IF;

	IF p_data_devolucao < v_aluguel.data_retirada THEN
		RAISE EXCEPTION 'A devolução não pode ser antes da retirada (%)', v_aluguel.data_retirada
			USING ERRCODE = 'LC005';
	END IF;

	IF p_km_devolucao < v_aluguel.km_retirada THEN
		RAISE EXCEPTION 'Km de devolução (%) menor que o de retirada (%)',
			p_km_devolucao, v_aluguel.km_retirada
			USING ERRCODE = 'LC005';
	END IF;

	v_total := calcular_valor(v_aluguel.valor_diaria, v_aluguel.data_retirada,
	                          v_aluguel.data_prevista_devolucao, p_data_devolucao);

	UPDATE aluguel
	   SET data_devolucao       = p_data_devolucao,
	       km_devolucao         = p_km_devolucao,
	       id_agencia_devolucao = p_id_agencia_devolucao,
	       valor_final          = v_total,
	       status               = 'FINALIZADO'
	 WHERE id_aluguel = p_id_aluguel;

	RETURN v_total;
END;
$$;

CREATE FUNCTION cancelar_aluguel(p_id_aluguel INT) RETURNS VOID
LANGUAGE plpgsql
SET search_path = locadora, pg_temp
AS $$
BEGIN
	UPDATE aluguel
	   SET status = 'CANCELADO'
	 WHERE id_aluguel = p_id_aluguel
	   AND status = 'EM_ANDAMENTO';

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Aluguel % não existe ou não está em andamento', p_id_aluguel
			USING ERRCODE = 'LC006';
	END IF;
END;
$$;
