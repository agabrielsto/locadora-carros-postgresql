-- Dados de exemplo (fictícios e determinísticos)
-- Os aluguéis 10 e 20 têm divergência de pagamento de propósito, para a view de conciliação listar.

SET search_path = locadora, public;

INSERT INTO agencia (nome, rua, numero, cidade, uf, telefone) VALUES
	('Rio - Centro',            'Rua Dias Coelho',         '100',  'Rio de Janeiro', 'RJ', '(21) 2222-2222'),
	('São Paulo - Bela Vista',  'Rua Alfredo Bittencourt', '250',  'São Paulo',      'SP', '(11) 3333-3333'),
	('Belo Horizonte - Savassi','Avenida Afonso Pena',     '1500', 'Belo Horizonte', 'MG', '(31) 3444-4444');

INSERT INTO funcionario (nome, cargo, id_agencia, data_admissao)
SELECT v.nome, v.cargo::cargo_funcionario, a.id_agencia, v.admissao
FROM (VALUES
	('Marcos Silva',   'GERENTE',   'Rio - Centro',             DATE '2019-03-01'),
	('Paula Souza',    'ATENDENTE', 'Rio - Centro',             DATE '2021-07-15'),
	('Renato Lima',    'GERENTE',   'São Paulo - Bela Vista',   DATE '2018-11-20'),
	('Juliana Costa',  'ATENDENTE', 'São Paulo - Bela Vista',   DATE '2022-01-10'),
	('Fernando Alves', 'GERENTE',   'Belo Horizonte - Savassi', DATE '2020-05-05'),
	('Camila Rocha',   'ATENDENTE', 'Belo Horizonte - Savassi', DATE '2023-02-27')
) AS v(nome, cargo, agencia, admissao)
JOIN agencia a ON a.nome = v.agencia;

INSERT INTO categoria (nome, valor_diaria) VALUES
	('Econômico',     120.00),
	('Intermediário', 180.00),
	('SUV',           250.00),
	('Luxo',          400.00);

INSERT INTO modelo (marca, nome, id_categoria)
SELECT v.marca, v.nome, c.id_categoria
FROM (VALUES
	('Honda',      'Civic',   'Intermediário'),
	('Chevrolet',  'Onix',    'Econômico'),
	('Fiat',       'Cronos',  'Econômico'),
	('Volkswagen', 'Polo',    'Econômico'),
	('Chevrolet',  'Tracker', 'SUV'),
	('Volkswagen', 'T-Cross', 'SUV'),
	('Toyota',     'Corolla', 'Intermediário'),
	('Toyota',     'Camry',   'Luxo'),
	('Hyundai',    'HB20',    'Econômico'),
	('Hyundai',    'Creta',   'SUV')
) AS v(marca, nome, categoria)
JOIN categoria c ON c.nome = v.categoria;

INSERT INTO carro (placa, id_modelo, id_agencia, ano, cor, combustivel, km_inicial)
SELECT v.placa, m.id_modelo, a.id_agencia, v.ano, v.cor, v.combustivel::combustivel_tipo, v.km
FROM (VALUES
	('ABC1D23', 'Civic',   'Rio - Centro',             2019, 'Prata',    'GASOLINA', 48200),
	('DDE8A90', 'Onix',    'Rio - Centro',             2021, 'Branco',   'FLEX',     21500),
	('FGI3B14', 'Cronos',  'São Paulo - Bela Vista',   2020, 'Preto',    'FLEX',     33800),
	('RIO2A45', 'Polo',    'Rio - Centro',             2022, 'Azul',     'FLEX',     15200),
	('RJB3C56', 'HB20',    'Rio - Centro',             2021, 'Vermelho', 'FLEX',     27400),
	('SPX4D67', 'Tracker', 'São Paulo - Bela Vista',   2022, 'Branco',   'FLEX',     18900),
	('SPY5E78', 'T-Cross', 'São Paulo - Bela Vista',   2023, 'Prata',    'FLEX',      9800),
	('SPZ6F89', 'Corolla', 'São Paulo - Bela Vista',   2020, 'Preto',    'FLEX',     41200),
	('BHA7G90', 'Creta',   'Belo Horizonte - Savassi', 2022, 'Branco',   'FLEX',     22300),
	('BHB8H01', 'Onix',    'Belo Horizonte - Savassi', 2021, 'Prata',    'FLEX',     30100),
	('BHC9J12', 'Cronos',  'Belo Horizonte - Savassi', 2020, 'Vermelho', 'FLEX',     38700),
	('RJD1K23', 'Civic',   'Rio - Centro',             2018, 'Preto',    'GASOLINA', 62500),
	('SPE2L34', 'Camry',   'São Paulo - Bela Vista',   2022, 'Preto',    'HIBRIDO',  19700),
	('BHF3M45', 'Corolla', 'Belo Horizonte - Savassi', 2023, 'Prata',    'HIBRIDO',   8700),
	('RJG4N56', 'Tracker', 'Rio - Centro',             2021, 'Azul',     'FLEX',     35600),
	('SPH5P67', 'HB20',    'São Paulo - Bela Vista',   2022, 'Branco',   'FLEX',     17400),
	('BHI6Q78', 'Polo',    'Belo Horizonte - Savassi', 2023, 'Prata',    'FLEX',     11200),
	('RJJ7R89', 'Creta',   'Rio - Centro',             2023, 'Preto',    'FLEX',     12800),
	('SPK8S90', 'Onix',    'São Paulo - Bela Vista',   2019, 'Vermelho', 'FLEX',     52300),
	('BHL9T01', 'T-Cross', 'Belo Horizonte - Savassi', 2022, 'Azul',     'FLEX',     24900)
) AS v(placa, modelo, agencia, ano, cor, combustivel, km)
JOIN modelo m  ON m.nome = v.modelo
JOIN agencia a ON a.nome = v.agencia
ORDER BY v.placa;

-- Mariana Cardoso e Felipe Ferreira têm CNH categoria A; Henrique Almeida tem CNH vencida
INSERT INTO cliente (nome, cpf, cnh, cnh_categoria, cnh_validade, email, telefone, data_nascimento) VALUES
	('André', '12346470872', '10007654321', 'B', DATE '2028-02-23', 'cliente01@exemplo.com', '(11) 91037-2011', DATE '1961-01-02'),
	('Bruna', '12347262700', '10015308642', 'AB', DATE '2028-04-16', 'cliente02@exemplo.com', '(31) 91074-2022', DATE '1962-01-04'),
	('Caio', '12348054647', '10022962963', 'B', DATE '2028-06-08', 'cliente03@exemplo.com', '(21) 91111-2033', DATE '1963-01-06'),
	('Diego', '12348846586', '10030617284', 'C', DATE '2028-07-31', 'cliente04@exemplo.com', '(11) 91148-2044', DATE '1964-01-08'),
	('Elisa', '12349638413', '10038271605', 'B', DATE '2028-09-22', 'cliente05@exemplo.com', '(31) 91185-2055', DATE '1965-01-09'),
	('Lucas Moreira', '12350430375', '10045925926', 'B', DATE '2028-11-14', 'cliente06@exemplo.com', '(21) 91222-2066', DATE '1966-01-11'),
	('Mariana Cardoso', '12351222202', '10053580247', 'A', DATE '2029-01-06', 'cliente07@exemplo.com', '(11) 91259-2077', DATE '1967-01-13'),
	('Nicolas Gomes', '12352014140', '10061234568', 'B', DATE '2029-02-28', 'cliente08@exemplo.com', '(31) 91296-2088', DATE '1968-01-15'),
	('Olívia Almeida', '12352806089', '10068888889', 'C', DATE '2029-04-22', 'cliente09@exemplo.com', '(21) 91333-2099', DATE '1969-01-16'),
	('Pedro Dias', '12353597947', '10076543210', 'B', DATE '2029-06-14', 'cliente10@exemplo.com', '(11) 91370-2110', DATE '1970-01-18'),
	('Felipe Lima', '12354389884', '10084197531', 'B', DATE '2029-08-06', 'cliente11@exemplo.com', '(31) 91407-2121', DATE '1971-01-20'),
	('Gabriela Barros', '12355181756', '10091851852', 'AB', DATE '2029-09-28', 'cliente12@exemplo.com', '(21) 91444-2132', DATE '1972-01-22'),
	('Henrique Ferreira', '12355973695', '10099506173', 'B', DATE '2029-11-20', 'cliente13@exemplo.com', '(11) 91481-2143', DATE '1973-01-23'),
	('Isabela Moreira', '12356765522', '10107160494', 'C', DATE '2028-02-12', 'cliente14@exemplo.com', '(31) 91518-2154', DATE '1974-01-25'),
	('Joana Cardoso', '12357557460', '10114814815', 'B', DATE '2028-04-05', 'cliente15@exemplo.com', '(21) 91555-2165', DATE '1975-01-27'),
	('Lucas Gomes', '12358349305', '10122469136', 'B', DATE '2028-05-28', 'cliente16@exemplo.com', '(11) 91592-2176', DATE '1976-01-29'),
	('Mariana Almeida', '12359141279', '10130123457', 'AB', DATE '2028-07-20', 'cliente17@exemplo.com', '(31) 91629-2187', DATE '1977-01-30'),
	('Nicolas Dias', '12359933108', '10137777778', 'B', DATE '2028-09-11', 'cliente18@exemplo.com', '(21) 91666-2198', DATE '1978-02-01'),
	('Olívia Lima', '12360725025', '10145432099', 'C', DATE '2028-11-03', 'cliente19@exemplo.com', '(11) 91703-2209', DATE '1979-02-03'),
	('Pedro Barros', '12361516900', '10153086420', 'B', DATE '2028-12-26', 'cliente20@exemplo.com', '(31) 91740-2220', DATE '1980-02-05'),
	('Felipe Ferreira', '12362308847', '10160740741', 'A', DATE '2029-02-17', 'cliente21@exemplo.com', '(21) 91777-2231', DATE '1981-02-06'),
	('Gabriela Moreira', '12363100719', '10168395062', 'AB', DATE '2029-04-11', 'cliente22@exemplo.com', '(11) 91814-2242', DATE '1982-02-08'),
	('Henrique Cardoso', '12363892631', '10176049383', 'B', DATE '2029-06-03', 'cliente23@exemplo.com', '(31) 91851-2253', DATE '1983-02-10'),
	('Isabela Gomes', '12364684579', '10183703704', 'C', DATE '2029-07-26', 'cliente24@exemplo.com', '(21) 91888-2264', DATE '1984-02-12'),
	('Joana Almeida', '12365476406', '10191358025', 'B', DATE '2029-09-17', 'cliente25@exemplo.com', '(11) 91925-2275', DATE '1985-02-13'),
	('Lucas Dias', '12366268343', '10199012346', 'B', DATE '2029-11-09', 'cliente26@exemplo.com', '(31) 91962-2286', DATE '1986-02-15'),
	('Mariana Lima', '12367060215', '10206666667', 'AB', DATE '2028-02-01', 'cliente27@exemplo.com', '(21) 91999-2297', DATE '1987-02-17'),
	('Nicolas Barros', '12367852154', '10214320988', 'B', DATE '2028-03-25', 'cliente28@exemplo.com', '(11) 92036-2308', DATE '1988-02-19'),
	('Olívia Ferreira', '12368644091', '10221975309', 'C', DATE '2028-05-17', 'cliente29@exemplo.com', '(31) 92073-2319', DATE '1989-02-20'),
	('Pedro Moreira', '12369435976', '10229629630', 'B', DATE '2028-07-09', 'cliente30@exemplo.com', '(21) 92110-2330', DATE '1990-02-22'),
	('Felipe Cardoso', '12370227893', '10237283951', 'B', DATE '2028-08-31', 'cliente31@exemplo.com', '(11) 92147-2341', DATE '1991-02-24'),
	('Gabriela Gomes', '12371019720', '10244938272', 'AB', DATE '2028-10-23', 'cliente32@exemplo.com', '(31) 92184-2352', DATE '1992-02-26'),
	('Henrique Almeida', '12371811602', '10252592593', 'B', DATE '2025-03-31', 'cliente33@exemplo.com', '(21) 92221-2363', DATE '1993-02-27'),
	('Isabela Dias', '12372603531', '10260246914', 'C', DATE '2029-02-06', 'cliente34@exemplo.com', '(11) 92258-2374', DATE '1994-03-01'),
	('Joana Lima', '12373395452', '10267901235', 'B', DATE '2029-03-31', 'cliente35@exemplo.com', '(31) 92295-2385', DATE '1995-03-03'),
	('Lucas Barros', '12374187390', '10275555556', 'B', DATE '2029-05-23', 'cliente36@exemplo.com', '(21) 92332-2396', DATE '1960-07-31'),
	('Mariana Ferreira', '12374979229', '10283209877', 'AB', DATE '2029-07-15', 'cliente37@exemplo.com', '(11) 92369-2407', DATE '1961-08-02'),
	('Nicolas Moreira', '12375771109', '10290864198', 'B', DATE '2029-09-06', 'cliente38@exemplo.com', '(31) 92406-2418', DATE '1962-08-04'),
	('Olívia Cardoso', '12376563038', '10298518519', 'C', DATE '2029-10-29', 'cliente39@exemplo.com', '(21) 92443-2429', DATE '1963-08-06'),
	('Pedro Gomes', '12377354912', '10306172840', 'B', DATE '2028-01-21', 'cliente40@exemplo.com', '(11) 92480-2440', DATE '1964-08-07');

-- histórico: 20 carros x 11 aluguéis finalizados, sem sobreposição de datas por carro
WITH clientes_ord AS (
	SELECT id_cliente, ROW_NUMBER() OVER (ORDER BY id_cliente) AS rn
	FROM cliente
	WHERE cnh_categoria <> 'A' AND cnh_validade >= DATE '2027-01-01'
),
total_clientes AS (
	SELECT COUNT(*) AS n FROM clientes_ord
),
base AS (
	SELECT c.id_carro,
	       c.id_agencia,
	       c.km_inicial,
	       cat.valor_diaria,
	       j,
	       DATE '2025-01-06' + (j - 1) * 55 + (c.id_carro % 7)  AS data_retirada,
	       2 + (c.id_carro * j) % 6                             AS dias_previstos,
	       CASE WHEN (c.id_carro + j) % 9 = 0 THEN 1 ELSE 0 END AS dias_atraso
	FROM carro c
	JOIN modelo m      ON m.id_modelo    = c.id_modelo
	JOIN categoria cat ON cat.id_categoria = m.id_categoria
	CROSS JOIN generate_series(1, 11) AS j
),
calc AS (
	SELECT b.*,
	       b.data_retirada + b.dias_previstos                    AS data_prevista,
	       b.data_retirada + b.dias_previstos + b.dias_atraso    AS data_devolucao,
	       (b.dias_previstos + b.dias_atraso) * 150              AS km_rodados
	FROM base b
),
fim AS (
	SELECT calc.*,
	       calc.km_inicial + COALESCE(
	           SUM(calc.km_rodados) OVER (
	               PARTITION BY calc.id_carro ORDER BY calc.j
	               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
	           ), 0) AS km_retirada
	FROM calc
)
INSERT INTO aluguel (
	id_cliente, id_carro, id_funcionario, id_agencia_retirada, id_agencia_devolucao,
	data_retirada, data_prevista_devolucao, data_devolucao,
	km_retirada, km_devolucao, valor_diaria, valor_previsto, valor_final, status
)
SELECT co.id_cliente,
       f.id_carro,
       (SELECT MIN(fu.id_funcionario)
          FROM funcionario fu
         WHERE fu.id_agencia = f.id_agencia AND fu.cargo = 'ATENDENTE'),
       f.id_agencia,
       f.id_agencia,
       f.data_retirada,
       f.data_prevista,
       f.data_devolucao,
       f.km_retirada,
       f.km_retirada + f.km_rodados,
       f.valor_diaria,
       calcular_valor(f.valor_diaria, f.data_retirada, f.data_prevista, f.data_prevista),
       calcular_valor(f.valor_diaria, f.data_retirada, f.data_prevista, f.data_devolucao),
       'FINALIZADO'::status_aluguel
FROM fim f
JOIN clientes_ord co
  ON co.rn = ((f.id_carro * 5 + f.j * 3) % (SELECT n FROM total_clientes)) + 1
ORDER BY f.data_retirada, f.id_carro;

-- aluguel 10 pago a menos, 20 sem pagamento, 30 cobrado a mais e estornado
INSERT INTO pagamento (id_aluguel, tipo, forma, valor, pago_em)
SELECT a.id_aluguel,
       'PAGAMENTO'::tipo_pagamento,
       (ARRAY['CARTAO_CREDITO', 'PIX', 'CARTAO_DEBITO', 'DINHEIRO'])[1 + a.id_aluguel % 4]::forma_pagamento,
       CASE a.id_aluguel
           WHEN 10 THEN a.valor_final - 10.00
           WHEN 30 THEN a.valor_final + 50.00
           ELSE a.valor_final
       END,
       (a.data_devolucao + TIME '18:00') AT TIME ZONE 'America/Sao_Paulo'
FROM aluguel a
WHERE a.status = 'FINALIZADO'
  AND a.id_aluguel <> 20;

INSERT INTO pagamento (id_aluguel, tipo, forma, valor, pago_em)
SELECT a.id_aluguel,
       'ESTORNO'::tipo_pagamento,
       'CARTAO_DEBITO'::forma_pagamento,
       50.00,
       ((a.data_devolucao + 2) + TIME '10:00') AT TIME ZONE 'America/Sao_Paulo'
FROM aluguel a
WHERE a.id_aluguel = 30;

-- duas manutenções por carro, fora dos períodos de aluguel
INSERT INTO manutencao (id_carro, tipo, descricao, data_entrada, data_saida, custo)
SELECT c.id_carro,
       m.tipo::tipo_manutencao,
       m.descricao,
       DATE '2025-01-06' + m.dia + (c.id_carro % 7),
       DATE '2025-01-06' + m.dia + (c.id_carro % 7) + 1,
       m.custo + c.id_carro * 5
FROM carro c
CROSS JOIN (VALUES
	('REVISAO',    'Revisão periódica',       185, 450.00),
	('TROCA_OLEO', 'Troca de óleo e filtros', 405, 220.00)
) AS m(tipo, descricao, dia, custo);

-- um carro na oficina agora (data_saida nula)
INSERT INTO manutencao (id_carro, tipo, descricao, data_entrada, data_saida, custo)
SELECT id_carro, 'FREIOS'::tipo_manutencao, 'Troca de pastilhas e discos (custo estimado)',
       DATE '2026-11-10', NULL::date, 780.00
FROM carro
WHERE placa = 'RJD1K23';

-- aluguéis em andamento, abertos pela mesma função usada pela aplicação
-- André: em dia (devolução prevista em 15/11)
SELECT abrir_aluguel(
	(SELECT id_cliente FROM cliente WHERE nome = 'André'),
	(SELECT id_carro FROM carro WHERE placa = 'ABC1D23'),
	(SELECT f.id_funcionario FROM funcionario f JOIN agencia a USING (id_agencia)
	  WHERE a.nome = 'Rio - Centro' AND f.cargo = 'ATENDENTE'),
	DATE '2026-11-10', DATE '2026-11-15');

-- Bruna: atrasada (devolução prevista em 07/11)
SELECT abrir_aluguel(
	(SELECT id_cliente FROM cliente WHERE nome = 'Bruna'),
	(SELECT id_carro FROM carro WHERE placa = 'FGI3B14'),
	(SELECT f.id_funcionario FROM funcionario f JOIN agencia a USING (id_agencia)
	  WHERE a.nome = 'São Paulo - Bela Vista' AND f.cargo = 'ATENDENTE'),
	DATE '2026-11-01', DATE '2026-11-07');

-- Caio: atrasado (devolução prevista em 09/11)
SELECT abrir_aluguel(
	(SELECT id_cliente FROM cliente WHERE nome = 'Caio'),
	(SELECT id_carro FROM carro WHERE placa = 'SPX4D67'),
	(SELECT f.id_funcionario FROM funcionario f JOIN agencia a USING (id_agencia)
	  WHERE a.nome = 'São Paulo - Bela Vista' AND f.cargo = 'ATENDENTE'),
	DATE '2026-11-05', DATE '2026-11-09');

-- Diego retira no Rio e devolve em São Paulo com 1 dia de atraso
SELECT abrir_aluguel(
	(SELECT id_cliente FROM cliente WHERE nome = 'Diego'),
	(SELECT id_carro FROM carro WHERE placa = 'DDE8A90'),
	(SELECT f.id_funcionario FROM funcionario f JOIN agencia a USING (id_agencia)
	  WHERE a.nome = 'Rio - Centro' AND f.cargo = 'ATENDENTE'),
	DATE '2026-11-02', DATE '2026-11-06');

SELECT finalizar_aluguel(
	(SELECT a.id_aluguel FROM aluguel a
	   JOIN carro c ON c.id_carro = a.id_carro
	  WHERE c.placa = 'DDE8A90' AND a.status = 'EM_ANDAMENTO'),
	(SELECT km_atual + 600 FROM vw_carros_status WHERE placa = 'DDE8A90'),
	(SELECT id_agencia FROM agencia WHERE nome = 'São Paulo - Bela Vista'),
	DATE '2026-11-07');

INSERT INTO pagamento (id_aluguel, tipo, forma, valor, pago_em)
SELECT a.id_aluguel, 'PAGAMENTO'::tipo_pagamento, 'PIX'::forma_pagamento, a.valor_final,
       (a.data_devolucao + TIME '18:00') AT TIME ZONE 'America/Sao_Paulo'
FROM aluguel a
JOIN carro c ON c.id_carro = a.id_carro
WHERE c.placa = 'DDE8A90' AND a.status = 'FINALIZADO' AND a.data_devolucao = DATE '2026-11-07';
