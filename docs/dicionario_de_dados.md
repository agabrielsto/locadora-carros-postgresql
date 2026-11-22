# Dicionário de dados

Schema `locadora` (camada operacional). Todas as FKs usam `ON DELETE RESTRICT`.
As mesmas descrições estão no banco (`COMMENT ON`) e podem ser consultadas com `\d+ nome_da_tabela`.

## Visão geral das tabelas

| Tabela | Relaciona-se com | Descrição |
|---|---|---|
| `agencia` | funcionario, carro, aluguel | Agências (filiais) |
| `funcionario` | agencia, aluguel | Funcionários de cada agência |
| `categoria` | modelo | Categoria do veículo e valor da diária |
| `modelo` | categoria, carro | Marca + nome do modelo |
| `carro` | modelo, agencia, aluguel, manutencao | Frota (status, km e agência atuais são derivados) |
| `cliente` | aluguel | Clientes (contém dados pessoais) |
| `aluguel` | cliente, carro, funcionario, agencia, pagamento | Aluguéis: cardinalidade **N:N** entre cliente e carro ao longo do tempo |
| `pagamento` | aluguel | Lançamentos de pagamento e estorno |
| `manutencao` | carro | Histórico de manutenções |

## agencia

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| id_agencia | INT (identity) | PK | Identificador da agência |
| nome | VARCHAR(60) | NOT NULL, UNIQUE | Nome da agência |
| rua | VARCHAR(100) | NOT NULL | Logradouro |
| numero | VARCHAR(10) | NOT NULL | Número |
| cidade | VARCHAR(60) | NOT NULL | Cidade |
| uf | VARCHAR(2) | NOT NULL, CHECK `^[A-Z]{2}$` | Sigla do estado |
| telefone | VARCHAR(20) | NOT NULL, CHECK formato `(DD) 9999-9999` | Contato telefônico |

## funcionario

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| id_funcionario | INT (identity) | PK | Identificador |
| nome | VARCHAR(100) | NOT NULL | Nome |
| cargo | ENUM `cargo_funcionario` | NOT NULL | `ATENDENTE` ou `GERENTE` |
| id_agencia | INT | NOT NULL, FK → agencia | Agência onde trabalha |
| data_admissao | DATE | NOT NULL | Data de admissão |

`UNIQUE (id_funcionario, id_agencia)` existe para servir de alvo da FK composta de `aluguel`.

## categoria

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| id_categoria | INT (identity) | PK | Identificador |
| nome | VARCHAR(50) | NOT NULL, UNIQUE | Econômico, Intermediário, SUV, Luxo |
| valor_diaria | NUMERIC(10,2) | NOT NULL, CHECK > 0 | Valor da diária vigente |

## modelo

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| id_modelo | INT (identity) | PK | Identificador |
| marca | VARCHAR(50) | NOT NULL | Marca (Honda, Fiat...) |
| nome | VARCHAR(50) | NOT NULL | Nome do modelo; `UNIQUE (marca, nome)` |
| id_categoria | INT | NOT NULL, FK → categoria | Categoria do modelo |

## carro

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| id_carro | INT (identity) | PK | Identificador |
| placa | VARCHAR(7) | NOT NULL, UNIQUE, CHECK `^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$` | Placa sem hífen (antiga ou Mercosul) |
| id_modelo | INT | NOT NULL, FK → modelo | Modelo |
| id_agencia | INT | NOT NULL, FK → agencia | Agência de **origem** (cadastro) |
| ano | INT | NOT NULL, CHECK 2000–2100 | Ano do carro |
| cor | VARCHAR(30) | NOT NULL | Cor |
| combustivel | ENUM `combustivel_tipo` | NOT NULL | GASOLINA, ETANOL, FLEX, DIESEL, ELETRICO, HIBRIDO |
| km_inicial | INT | NOT NULL, DEFAULT 0, CHECK >= 0 | Km no cadastro. O km atual vem de `vw_carros_status` |

## cliente

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| id_cliente | INT (identity) | PK | Identificador |
| nome | VARCHAR(100) | NOT NULL | Nome |
| cpf | VARCHAR(11) | NOT NULL, UNIQUE, CHECK `cpf_valido()` | CPF (só dígitos, com dígito verificador válido) |
| cnh | VARCHAR(11) | NOT NULL, UNIQUE, CHECK 11 dígitos | Número da CNH |
| cnh_categoria | VARCHAR(2) | NOT NULL, CHECK IN (A, B, AB, C, D, E) | Categoria da habilitação |
| cnh_validade | DATE | NOT NULL | Validade da CNH |
| email | VARCHAR(120) | NOT NULL, UNIQUE, CHECK formato | E-mail |
| telefone | VARCHAR(20) | NOT NULL, CHECK formato | Telefone |
| data_nascimento | DATE | NOT NULL, CHECK > 1900-01-01 | Data de nascimento |

## aluguel

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| id_aluguel | INT (identity) | PK | Identificador |
| id_cliente | INT | NOT NULL, FK → cliente | Quem alugou |
| id_carro | INT | NOT NULL, FK → carro | Carro alugado |
| id_funcionario | INT | NOT NULL, FK composta → funcionario | Quem atendeu |
| id_agencia_retirada | INT | NOT NULL, FK composta → funcionario | Onde o carro foi retirado (o funcionário precisa ser desta agência) |
| id_agencia_devolucao | INT | FK → agencia | Onde foi devolvido (NULL até a devolução) |
| data_retirada | DATE | NOT NULL | Data da retirada |
| data_prevista_devolucao | DATE | NOT NULL, CHECK > data_retirada | Devolução combinada |
| data_devolucao | DATE | CHECK >= data_retirada | Devolução real (NULL até a devolução) |
| km_retirada | INT | NOT NULL, CHECK >= 0 | Km no momento da retirada |
| km_devolucao | INT | CHECK >= km_retirada | Km na devolução (NULL até a devolução) |
| valor_diaria | NUMERIC(10,2) | NOT NULL, CHECK > 0 | Diária **congelada** no dia do aluguel |
| valor_previsto | NUMERIC(10,2) | NOT NULL, CHECK > 0 | Estimativa ao abrir o aluguel |
| valor_final | NUMERIC(10,2) | CHECK > 0 | Valor cobrado (NULL até a devolução) |
| status | ENUM `status_aluguel` | NOT NULL, DEFAULT `EM_ANDAMENTO` | `EM_ANDAMENTO`, `FINALIZADO` ou `CANCELADO` |

Regras garantidas pelo banco:

- `ck_aluguel_estado`: `FINALIZADO` exige data, km, valor e agência de devolução; os demais status não podem tê-los.
- `ex_aluguel_sem_sobreposicao`: o mesmo carro não pode ter dois aluguéis (não cancelados) com períodos sobrepostos.

## pagamento

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| id_pagamento | INT (identity) | PK | Identificador |
| id_aluguel | INT | NOT NULL, FK → aluguel | Aluguel pago |
| tipo | ENUM `tipo_pagamento` | NOT NULL, DEFAULT `PAGAMENTO` | `PAGAMENTO` ou `ESTORNO` |
| forma | ENUM `forma_pagamento` | NOT NULL | CARTAO_CREDITO, CARTAO_DEBITO, PIX, DINHEIRO |
| valor | NUMERIC(10,2) | NOT NULL, CHECK > 0 | Valor do lançamento (sempre positivo; o tipo define o sinal) |
| pago_em | TIMESTAMPTZ | NOT NULL | Momento do lançamento |

## manutencao

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| id_manutencao | INT (identity) | PK | Identificador |
| id_carro | INT | NOT NULL, FK → carro | Carro na manutenção |
| tipo | ENUM `tipo_manutencao` | NOT NULL | REVISAO, TROCA_OLEO, PNEUS, FREIOS, FUNILARIA, OUTRO |
| descricao | VARCHAR(200) | NOT NULL | Descrição do serviço |
| data_entrada | DATE | NOT NULL | Entrada na oficina |
| data_saida | DATE | CHECK >= data_entrada | Saída (NULL = ainda na oficina) |
| custo | NUMERIC(10,2) | NOT NULL, DEFAULT 0, CHECK >= 0 | Custo do serviço |

## Views (schema `locadora`)

| View | Descrição |
|---|---|
| `vw_carros_status` | Situação (`ALUGADO`, `MANUTENCAO`, `DISPONIVEL`), km e agência atuais de cada carro |
| `vw_alugueis_ativos` | Aluguéis em andamento, com dias de atraso em relação a `hoje()` |
| `vw_conciliacao_pagamentos` | Aluguéis finalizados em que o valor pago difere do valor cobrado |

## Funções

| Função | Descrição |
|---|---|
| `abrir_aluguel(cliente, carro, funcionario, retirada, prevista)` | Valida e registra a retirada; retorna o id |
| `finalizar_aluguel(aluguel, km, agencia_devolucao, data)` | Registra a devolução e retorna o valor final |
| `cancelar_aluguel(aluguel)` | Cancela um aluguel em andamento |
| `calcular_valor(diaria, retirada, prevista, devolucao)` | Regra de preço (diárias reais + 20% por dia de atraso) |
| `cpf_valido(cpf)` | Valida os dígitos verificadores do CPF |
| `hoje()` | Data de referência (fuso America/Sao_Paulo ou `app.data_referencia`) |

## Schema `dw` (camada analítica)

| Objeto | Tipo | Grão / conteúdo |
|---|---|---|
| `dim_data` | Materialized view | 1 linha por dia (2025–2027): ano, trimestre, mês, dia da semana, fim de semana |
| `dim_cliente` | Materialized view | Cliente sem CPF, CNH, e-mail e telefone; inclui década de nascimento |
| `dim_carro` | Materialized view | Placa, marca, modelo, categoria, ano, combustível |
| `dim_agencia` | Materialized view | Agência, cidade e UF |
| `fato_aluguel` | Materialized view | 1 linha por aluguel finalizado. Medidas: `qtd_dias`, `dias_atraso`, `km_rodados`, `valor_diaria`, `valor_final` |
| `atualizar()` | Função | Recarrega dimensões e fato |
