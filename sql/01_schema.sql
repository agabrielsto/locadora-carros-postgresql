-- Schema locadora: tipos, tabelas e índices

-- btree_gist é necessária para a constraint EXCLUDE de aluguel
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE SCHEMA IF NOT EXISTS locadora;
SET search_path = locadora, public;

CREATE TYPE status_aluguel    AS ENUM ('EM_ANDAMENTO', 'FINALIZADO', 'CANCELADO');
CREATE TYPE combustivel_tipo  AS ENUM ('GASOLINA', 'ETANOL', 'FLEX', 'DIESEL', 'ELETRICO', 'HIBRIDO');
CREATE TYPE tipo_manutencao   AS ENUM ('REVISAO', 'TROCA_OLEO', 'PNEUS', 'FREIOS', 'FUNILARIA', 'OUTRO');
CREATE TYPE tipo_pagamento    AS ENUM ('PAGAMENTO', 'ESTORNO');
CREATE TYPE forma_pagamento   AS ENUM ('CARTAO_CREDITO', 'CARTAO_DEBITO', 'PIX', 'DINHEIRO');
CREATE TYPE cargo_funcionario AS ENUM ('ATENDENTE', 'GERENTE');

-- valida os dígitos verificadores do CPF (usada em CHECK na tabela cliente)
CREATE FUNCTION cpf_valido(p_cpf TEXT) RETURNS BOOLEAN
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
	d    INT[];
	soma INT;
	i    INT;
	dv1  INT;
	dv2  INT;
BEGIN
	IF p_cpf !~ '^[0-9]{11}$' OR p_cpf ~ '^(.)\1{10}$' THEN
		RETURN FALSE;
	END IF;

	FOR i IN 1..11 LOOP
		d[i] := substr(p_cpf, i, 1)::INT;
	END LOOP;

	soma := 0;
	FOR i IN 1..9 LOOP
		soma := soma + d[i] * (11 - i);
	END LOOP;
	dv1 := (soma * 10) % 11;
	IF dv1 = 10 THEN dv1 := 0; END IF;

	soma := 0;
	FOR i IN 1..10 LOOP
		soma := soma + d[i] * (12 - i);
	END LOOP;
	dv2 := (soma * 10) % 11;
	IF dv2 = 10 THEN dv2 := 0; END IF;

	RETURN dv1 = d[10] AND dv2 = d[11];
END;
$$;

CREATE TABLE agencia (
	id_agencia INT GENERATED ALWAYS AS IDENTITY,
	nome       VARCHAR(60)  NOT NULL,
	rua        VARCHAR(100) NOT NULL,
	numero     VARCHAR(10)  NOT NULL,
	cidade     VARCHAR(60)  NOT NULL,
	uf         VARCHAR(2)   NOT NULL,
	telefone   VARCHAR(20)  NOT NULL,
	CONSTRAINT pk_agencia          PRIMARY KEY (id_agencia),
	CONSTRAINT uq_agencia_nome     UNIQUE (nome),
	CONSTRAINT ck_agencia_uf       CHECK (uf ~ '^[A-Z]{2}$'),
	CONSTRAINT ck_agencia_telefone CHECK (telefone ~ '^\(\d{2}\) \d{4,5}-\d{4}$')
);

CREATE TABLE funcionario (
	id_funcionario INT GENERATED ALWAYS AS IDENTITY,
	nome           VARCHAR(100)      NOT NULL,
	cargo          cargo_funcionario NOT NULL,
	id_agencia     INT               NOT NULL,
	data_admissao  DATE              NOT NULL,
	CONSTRAINT pk_funcionario PRIMARY KEY (id_funcionario),
	CONSTRAINT fk_funcionario_agencia FOREIGN KEY (id_agencia)
		REFERENCES agencia (id_agencia) ON DELETE RESTRICT,
	CONSTRAINT uq_funcionario_agencia UNIQUE (id_funcionario, id_agencia)
);

CREATE TABLE categoria (
	id_categoria INT GENERATED ALWAYS AS IDENTITY,
	nome         VARCHAR(50)   NOT NULL,
	valor_diaria NUMERIC(10,2) NOT NULL,
	CONSTRAINT pk_categoria PRIMARY KEY (id_categoria),
	CONSTRAINT uq_categoria_nome UNIQUE (nome),
	CONSTRAINT ck_categoria_valor CHECK (valor_diaria > 0)
);

CREATE TABLE modelo (
	id_modelo    INT GENERATED ALWAYS AS IDENTITY,
	marca        VARCHAR(50) NOT NULL,
	nome         VARCHAR(50) NOT NULL,
	id_categoria INT         NOT NULL,
	CONSTRAINT pk_modelo PRIMARY KEY (id_modelo),
	CONSTRAINT uq_modelo_marca_nome UNIQUE (marca, nome),
	CONSTRAINT fk_modelo_categoria FOREIGN KEY (id_categoria)
		REFERENCES categoria (id_categoria) ON DELETE RESTRICT
);

-- status, km atual e agência atual não são colunas: saem da view vw_carros_status
CREATE TABLE carro (
	id_carro    INT GENERATED ALWAYS AS IDENTITY,
	placa       VARCHAR(7)        NOT NULL,
	id_modelo   INT               NOT NULL,
	id_agencia  INT               NOT NULL,
	ano         INT               NOT NULL,
	cor         VARCHAR(30)       NOT NULL,
	combustivel combustivel_tipo  NOT NULL,
	km_inicial  INT               NOT NULL DEFAULT 0,
	CONSTRAINT pk_carro PRIMARY KEY (id_carro),
	CONSTRAINT uq_carro_placa UNIQUE (placa),
	CONSTRAINT fk_carro_modelo FOREIGN KEY (id_modelo)
		REFERENCES modelo (id_modelo) ON DELETE RESTRICT,
	CONSTRAINT fk_carro_agencia FOREIGN KEY (id_agencia)
		REFERENCES agencia (id_agencia) ON DELETE RESTRICT,
	CONSTRAINT ck_carro_placa CHECK (placa ~ '^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$'),
	CONSTRAINT ck_carro_ano   CHECK (ano BETWEEN 2000 AND 2100),
	CONSTRAINT ck_carro_km    CHECK (km_inicial >= 0)
);

CREATE TABLE cliente (
	id_cliente      INT GENERATED ALWAYS AS IDENTITY,
	nome            VARCHAR(100) NOT NULL,
	cpf             VARCHAR(11)  NOT NULL,
	cnh             VARCHAR(11)  NOT NULL,
	cnh_categoria   VARCHAR(2)   NOT NULL,
	cnh_validade    DATE         NOT NULL,
	email           VARCHAR(120) NOT NULL,
	telefone        VARCHAR(20)  NOT NULL,
	data_nascimento DATE         NOT NULL,
	CONSTRAINT pk_cliente PRIMARY KEY (id_cliente),
	CONSTRAINT uq_cliente_cpf   UNIQUE (cpf),
	CONSTRAINT uq_cliente_cnh   UNIQUE (cnh),
	CONSTRAINT uq_cliente_email UNIQUE (email),
	CONSTRAINT ck_cliente_cpf        CHECK (cpf_valido(cpf)),
	CONSTRAINT ck_cliente_cnh        CHECK (cnh ~ '^[0-9]{11}$'),
	CONSTRAINT ck_cliente_cnh_cat    CHECK (cnh_categoria IN ('A', 'B', 'AB', 'C', 'D', 'E')),
	CONSTRAINT ck_cliente_email      CHECK (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
	CONSTRAINT ck_cliente_telefone   CHECK (telefone ~ '^\(\d{2}\) \d{4,5}-\d{4}$'),
	CONSTRAINT ck_cliente_nascimento CHECK (data_nascimento > DATE '1900-01-01')
);

CREATE TABLE aluguel (
	id_aluguel              INT GENERATED ALWAYS AS IDENTITY,
	id_cliente              INT            NOT NULL,
	id_carro                INT            NOT NULL,
	id_funcionario          INT            NOT NULL,
	id_agencia_retirada     INT            NOT NULL,
	id_agencia_devolucao    INT,                       -- só se sabe na devolução
	data_retirada           DATE           NOT NULL,
	data_prevista_devolucao DATE           NOT NULL,
	data_devolucao          DATE,                      -- NULL enquanto em andamento
	km_retirada             INT            NOT NULL,
	km_devolucao            INT,
	valor_diaria            NUMERIC(10,2)  NOT NULL,   -- congelado no dia do aluguel
	valor_previsto          NUMERIC(10,2)  NOT NULL,
	valor_final             NUMERIC(10,2),             -- calculado na devolução
	status                  status_aluguel NOT NULL DEFAULT 'EM_ANDAMENTO',
	CONSTRAINT pk_aluguel PRIMARY KEY (id_aluguel),
	CONSTRAINT fk_aluguel_cliente FOREIGN KEY (id_cliente)
		REFERENCES cliente (id_cliente) ON DELETE RESTRICT,
	CONSTRAINT fk_aluguel_carro FOREIGN KEY (id_carro)
		REFERENCES carro (id_carro) ON DELETE RESTRICT,
	-- o funcionário precisa ser da agência de retirada
	CONSTRAINT fk_aluguel_funcionario FOREIGN KEY (id_funcionario, id_agencia_retirada)
		REFERENCES funcionario (id_funcionario, id_agencia) ON DELETE RESTRICT,
	CONSTRAINT fk_aluguel_ag_devolucao FOREIGN KEY (id_agencia_devolucao)
		REFERENCES agencia (id_agencia) ON DELETE RESTRICT,
	CONSTRAINT ck_aluguel_datas CHECK (data_prevista_devolucao > data_retirada),
	CONSTRAINT ck_aluguel_devolucao CHECK (data_devolucao IS NULL OR data_devolucao >= data_retirada),
	CONSTRAINT ck_aluguel_km CHECK (km_retirada >= 0 AND (km_devolucao IS NULL OR km_devolucao >= km_retirada)),
	CONSTRAINT ck_aluguel_valores CHECK (
		valor_diaria > 0 AND valor_previsto > 0 AND (valor_final IS NULL OR valor_final > 0)
	),
	-- FINALIZADO tem todos os dados de devolução; os outros status não têm nenhum
	CONSTRAINT ck_aluguel_estado CHECK (
		(status = 'FINALIZADO'
			AND data_devolucao IS NOT NULL AND km_devolucao IS NOT NULL
			AND valor_final IS NOT NULL AND id_agencia_devolucao IS NOT NULL)
		OR
		(status <> 'FINALIZADO'
			AND data_devolucao IS NULL AND km_devolucao IS NULL
			AND valor_final IS NULL AND id_agencia_devolucao IS NULL)
	),
	-- o mesmo carro não pode ter dois aluguéis ao mesmo tempo (intervalo aberto até a devolução)
	CONSTRAINT ex_aluguel_sem_sobreposicao EXCLUDE USING gist (
		id_carro WITH =,
		daterange(data_retirada, data_devolucao, '[)') WITH &&
	) WHERE (status <> 'CANCELADO')
);

-- pagamento e estorno são lançamentos; saldo = pagamentos - estornos
CREATE TABLE pagamento (
	id_pagamento INT GENERATED ALWAYS AS IDENTITY,
	id_aluguel   INT             NOT NULL,
	tipo         tipo_pagamento  NOT NULL DEFAULT 'PAGAMENTO',
	forma        forma_pagamento NOT NULL,
	valor        NUMERIC(10,2)   NOT NULL,
	pago_em      TIMESTAMPTZ     NOT NULL,
	CONSTRAINT pk_pagamento PRIMARY KEY (id_pagamento),
	CONSTRAINT fk_pagamento_aluguel FOREIGN KEY (id_aluguel)
		REFERENCES aluguel (id_aluguel) ON DELETE RESTRICT,
	CONSTRAINT ck_pagamento_valor CHECK (valor > 0)
);

CREATE TABLE manutencao (
	id_manutencao INT GENERATED ALWAYS AS IDENTITY,
	id_carro      INT             NOT NULL,
	tipo          tipo_manutencao NOT NULL,
	descricao     VARCHAR(200)    NOT NULL,
	data_entrada  DATE            NOT NULL,
	data_saida    DATE,                          -- NULL = carro ainda na oficina
	custo         NUMERIC(10,2)   NOT NULL DEFAULT 0,
	CONSTRAINT pk_manutencao PRIMARY KEY (id_manutencao),
	CONSTRAINT fk_manutencao_carro FOREIGN KEY (id_carro)
		REFERENCES carro (id_carro) ON DELETE RESTRICT,
	CONSTRAINT ck_manutencao_datas CHECK (data_saida IS NULL OR data_saida >= data_entrada),
	CONSTRAINT ck_manutencao_custo CHECK (custo >= 0)
);

-- índices nas FKs (o Postgres não cria automaticamente)
CREATE INDEX idx_funcionario_agencia  ON funcionario (id_agencia);
CREATE INDEX idx_modelo_categoria     ON modelo (id_categoria);
CREATE INDEX idx_carro_modelo         ON carro (id_modelo);
CREATE INDEX idx_carro_agencia        ON carro (id_agencia);
CREATE INDEX idx_aluguel_cliente      ON aluguel (id_cliente);
CREATE INDEX idx_aluguel_carro        ON aluguel (id_carro);
CREATE INDEX idx_aluguel_funcionario  ON aluguel (id_funcionario, id_agencia_retirada);
CREATE INDEX idx_aluguel_ag_devolucao ON aluguel (id_agencia_devolucao);
CREATE INDEX idx_pagamento_aluguel    ON pagamento (id_aluguel);
CREATE INDEX idx_manutencao_carro     ON manutencao (id_carro);

-- índices parciais
CREATE INDEX idx_aluguel_em_andamento ON aluguel (id_carro) WHERE status = 'EM_ANDAMENTO';
CREATE INDEX idx_aluguel_finalizado   ON aluguel (data_devolucao) WHERE status = 'FINALIZADO';
CREATE INDEX idx_manutencao_aberta    ON manutencao (id_carro) WHERE data_saida IS NULL;

COMMENT ON TABLE agencia     IS 'Agências (filiais) da locadora';
COMMENT ON TABLE funcionario IS 'Funcionários, vinculados a uma agência';
COMMENT ON TABLE categoria   IS 'Categorias de veículo e valor da diária';
COMMENT ON TABLE modelo      IS 'Modelos de veículo (marca + nome) e sua categoria';
COMMENT ON TABLE carro       IS 'Frota. Status, km e agência atuais são derivados: ver vw_carros_status';
COMMENT ON TABLE cliente     IS 'Clientes. Contém dados pessoais (CPF, CNH): tratar conforme a LGPD';
COMMENT ON TABLE aluguel     IS 'Aluguéis. Relação N:N entre cliente e carro ao longo do tempo';
COMMENT ON TABLE pagamento   IS 'Lançamentos financeiros (pagamentos e estornos) de cada aluguel';
COMMENT ON TABLE manutencao  IS 'Histórico de manutenções; data_saida NULL = carro na oficina';
COMMENT ON COLUMN aluguel.valor_diaria  IS 'Diária congelada no dia do aluguel; não muda se a categoria mudar de preço';
COMMENT ON COLUMN aluguel.valor_previsto IS 'Valor estimado ao abrir o aluguel (dias previstos, sem atraso)';
COMMENT ON COLUMN aluguel.valor_final   IS 'Valor cobrado, calculado em finalizar_aluguel()';
