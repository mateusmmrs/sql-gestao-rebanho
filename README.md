<h1 align="center">
  SQL para Gestão de Rebanho
</h1>

<p align="center">
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white" />
  <img src="https://img.shields.io/badge/SQL-4479A1?logo=postgresql&logoColor=white" />
  <img src="https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white" />
</p>

Banco PostgreSQL com tabelas de gestão pecuária e 20 queries estratégicas que resolvem problemas reais de uma operação de corte.

A ideia surgiu de algo que sempre me incomodou: a maioria das fazendas ainda usa planilha Excel (ou pior, caderno) pra controlar o rebanho. Modelei o banco de dados que eu gostaria que existisse — e escrevi as queries que um gerente de fazenda realmente precisaria no dia a dia.

---

## O que tem aqui

- **`schema.sql`** — 9 tabelas com relacionamentos, constraints e índices
- **`queries.sql`** — 20 queries comentadas, organizadas por área
- **`seed_data.sql`** — ~800 animais, 3 fazendas, dados de 4 estações de monta
- **`scripts/generate_seed_data.py`** — Script que gera os dados de teste

---

## Tabelas

```
fazendas ──── lotes
    │            │
    │         animais ──── touros
    │            │
    │     ┌──────┼──────────────┐
    │     │      │              │
    │  pesagens  │    eventos_sanitarios
    │            │
    │   ┌────────┼────────┐
    │   │        │        │
    │  partos  diag_gestacao  movimentacoes
    │
    └── financeiro ── estacoes_monta
```

---

## As 20 Queries

Organizei por área de negócio. Cada query tem um comentário explicando **por que ela importa** pro gerente da fazenda.

### Reprodução (1-5)

| # | Query | O que faz |
|---|-------|-----------|
| 1 | Vacas 2+ falhas consecutivas | Identifica candidatas a descarte por falha reprodutiva |
| 2 | Taxa de prenhez por fazenda/raça | KPI principal da reprodução |
| 3 | Performance por touro | Cruza DEPs, preço pago e taxa de prenhez real |
| 4 | Vacas com ECC < 5 | Risco reprodutivo — precisa suplementar antes da monta |
| 5 | Intervalo entre partos | IEP médio por vaca (ideal < 365 dias) |

### Desempenho (6-10)

| # | Query | O que faz |
|---|-------|-----------|
| 6 | GMD por lote | Ganho médio diário nos últimos 90 dias |
| 7 | Sem pesagem 60+ dias | Alerta de manejo — animal pode estar perdido |
| 8 | Previsão de abate | Lotes com peso próximo de 18@ (540 kg) |
| 9 | Peso desmama por touro | Avalia retorno genético |
| 10 | Curva de crescimento por raça | Peso médio por faixa etária |

### Sanidade (11-13)

| # | Query | O que faz |
|---|-------|-----------|
| 11 | Custo sanitário por cabeça | Identifica fazenda com custo excessivo |
| 12 | Vacinas vencidas | Alerta pra evitar multa e bloqueio de GTA |
| 13 | Taxa de mortalidade | Bezerros >3% ou adultos >1% = problema |

### Financeiro e gestão (14-17)

| # | Query | O que faz |
|---|-------|-----------|
| 14 | Resultado por fazenda | Receita - despesa por fazenda |
| 15 | Custo por arroba | Viabilidade econômica do lote de engorda |
| 16 | Lotação (UA/ha) | Superlotação degrada pasto, sublotação desperdiça terra |
| 17 | Ranking reprodutivo | Compara fazendas por taxa de prenhez |

### Views para dashboard (18-20)

| # | Query | O que faz |
|---|-------|-----------|
| 18 | vw_kpis_fazenda | KPIs consolidados (animais, matrizes, mortes) |
| 19 | vw_historico_reprodutivo | Ficha individual da vaca |
| 20 | vw_alertas_rebanho | Consolidado de alertas (ECC, pesagem, vacina) |

---

## Conceitos SQL demonstrados

- `JOINs` complexos (5+ tabelas)
- `CTEs` (Common Table Expressions) com `WITH`
- `Window Functions` — `LAG`, `ROW_NUMBER`, `RANK`
- `LATERAL JOIN` pra subquery correlacionada
- `FILTER` clause (PostgreSQL)
- `CASE WHEN` pra classificação
- `GROUP BY` com `HAVING`
- Views materializadas (`CREATE VIEW`)
- Aggregações condicionais
- Subqueries correlacionadas

---

## Stack Tecnológica

| Tecnologia | Aplicação |
|-----------|-----------|
| PostgreSQL | Banco de dados relacional e schema produtivo |
| SQL | DDL, DML, CTEs, e Window Functions |
| Python | Geração de dados simulados (estruturas complexas) |

---

## Como rodar

Se tiver PostgreSQL instalado:

```bash
# Criar banco
createdb gestao_rebanho

# Criar tabelas
psql -d gestao_rebanho -f schema.sql

# Popular com dados de exemplo
psql -d gestao_rebanho -f seed_data.sql

# Rodar queries
psql -d gestao_rebanho -f queries.sql
```

Sem PostgreSQL, dá pra ler o `schema.sql` e `queries.sql` direto — o código é a parte importante.

---

## Estrutura

```
sql-gestao-rebanho/
├── schema.sql          # DDL — 9 tabelas + índices
├── queries.sql         # 20 queries estratégicas comentadas
├── seed_data.sql       # Dados de exemplo (~800 animais)
├── scripts/
│   └── generate_seed_data.py  # Gerador dos dados
└── README.md
```

---

**Mateus Martins** · Médico Veterinário · Analista de Dados
