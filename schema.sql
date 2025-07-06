-- ============================================================
-- SCHEMA: Sistema de Gestão Pecuária
-- Banco: PostgreSQL
-- Modelagem para gestão operacional de fazendas de corte
-- ============================================================

CREATE TABLE fazendas (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    uf CHAR(2) NOT NULL,
    municipio VARCHAR(100),
    area_ha NUMERIC(10,2),
    sistema VARCHAR(30) CHECK (sistema IN ('extensivo','semi-intensivo','intensivo')),
    capacidade_ua INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE lotes (
    id SERIAL PRIMARY KEY,
    fazenda_id INTEGER REFERENCES fazendas(id),
    nome VARCHAR(50) NOT NULL,
    tipo VARCHAR(30) CHECK (tipo IN ('cria','recria','engorda','reproducao','descarte')),
    pasto VARCHAR(50),
    area_ha NUMERIC(8,2),
    ativo BOOLEAN DEFAULT TRUE
);

CREATE TABLE animais (
    id SERIAL PRIMARY KEY,
    brinco VARCHAR(20) UNIQUE NOT NULL,
    nome VARCHAR(50),
    sexo CHAR(1) CHECK (sexo IN ('M','F')),
    raca VARCHAR(50) NOT NULL,
    data_nascimento DATE,
    fazenda_id INTEGER REFERENCES fazendas(id),
    lote_id INTEGER REFERENCES lotes(id),
    mae_id INTEGER REFERENCES animais(id),
    pai_id INTEGER REFERENCES animais(id),
    categoria VARCHAR(30) CHECK (categoria IN (
        'bezerro','bezerra','novilho','novilha',
        'touro','vaca','boi','descarte'
    )),
    status VARCHAR(20) DEFAULT 'ativo' CHECK (status IN ('ativo','vendido','morto','descartado')),
    data_entrada DATE,
    data_saida DATE,
    motivo_saida VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE touros (
    id SERIAL PRIMARY KEY,
    animal_id INTEGER REFERENCES animais(id) UNIQUE,
    registro_genealogico VARCHAR(30),
    dep_peso_desmama NUMERIC(6,2),
    dep_peso_sobreano NUMERIC(6,2),
    dep_perimetro_escrotal NUMERIC(6,2),
    dep_fertilidade NUMERIC(6,2),
    preco_aquisicao NUMERIC(10,2),
    data_aquisicao DATE,
    aptidao VARCHAR(20) DEFAULT 'ativo'
);

CREATE TABLE estacoes_monta (
    id SERIAL PRIMARY KEY,
    fazenda_id INTEGER REFERENCES fazendas(id),
    ano INTEGER NOT NULL,
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    protocolo VARCHAR(50),
    observacoes TEXT
);

CREATE TABLE diagnosticos_gestacao (
    id SERIAL PRIMARY KEY,
    animal_id INTEGER REFERENCES animais(id),
    estacao_id INTEGER REFERENCES estacoes_monta(id),
    data_diagnostico DATE NOT NULL,
    resultado VARCHAR(20) CHECK (resultado IN ('prenhe','vazia','perda')),
    dias_gestacao INTEGER,
    touro_id INTEGER REFERENCES touros(id),
    metodo VARCHAR(30) DEFAULT 'ultrassom',
    ecc NUMERIC(3,1),
    observacoes TEXT
);

CREATE TABLE partos (
    id SERIAL PRIMARY KEY,
    mae_id INTEGER REFERENCES animais(id),
    bezerro_id INTEGER REFERENCES animais(id),
    data_parto DATE NOT NULL,
    tipo_parto VARCHAR(20) CHECK (tipo_parto IN ('normal','distocico','cesariana','natimorto')),
    peso_nascimento NUMERIC(5,2),
    sexo_bezerro CHAR(1),
    estacao_id INTEGER REFERENCES estacoes_monta(id)
);

CREATE TABLE pesagens (
    id SERIAL PRIMARY KEY,
    animal_id INTEGER REFERENCES animais(id),
    data_pesagem DATE NOT NULL,
    peso_kg NUMERIC(6,2) NOT NULL,
    tipo VARCHAR(30) CHECK (tipo IN ('nascimento','desmama','sobreano','rotina','embarque','abate')),
    ecc NUMERIC(3,1),
    lote_id INTEGER REFERENCES lotes(id)
);

CREATE TABLE eventos_sanitarios (
    id SERIAL PRIMARY KEY,
    animal_id INTEGER REFERENCES animais(id),
    data_evento DATE NOT NULL,
    tipo VARCHAR(50) CHECK (tipo IN ('vacinacao','vermifugacao','tratamento','exame','cirurgia','obito')),
    descricao VARCHAR(200) NOT NULL,
    produto VARCHAR(100),
    dose VARCHAR(50),
    custo NUMERIC(10,2),
    veterinario VARCHAR(100),
    proxima_dose DATE
);

CREATE TABLE movimentacoes (
    id SERIAL PRIMARY KEY,
    animal_id INTEGER REFERENCES animais(id),
    data_movimentacao DATE NOT NULL,
    tipo VARCHAR(30) CHECK (tipo IN ('entrada','saida','transferencia','venda','compra','obito')),
    lote_origem_id INTEGER REFERENCES lotes(id),
    lote_destino_id INTEGER REFERENCES lotes(id),
    motivo VARCHAR(200),
    peso_kg NUMERIC(6,2),
    valor NUMERIC(12,2)
);

CREATE TABLE financeiro (
    id SERIAL PRIMARY KEY,
    fazenda_id INTEGER REFERENCES fazendas(id),
    data_lancamento DATE NOT NULL,
    tipo VARCHAR(20) CHECK (tipo IN ('receita','despesa')),
    categoria VARCHAR(50) NOT NULL,
    subcategoria VARCHAR(50),
    descricao VARCHAR(200),
    valor NUMERIC(12,2) NOT NULL,
    animal_id INTEGER REFERENCES animais(id),
    lote_id INTEGER REFERENCES lotes(id)
);

-- ÍNDICES
CREATE INDEX idx_animais_fazenda ON animais(fazenda_id);
CREATE INDEX idx_animais_lote ON animais(lote_id);
CREATE INDEX idx_animais_status ON animais(status);
CREATE INDEX idx_pesagens_animal ON pesagens(animal_id);
CREATE INDEX idx_pesagens_data ON pesagens(data_pesagem);
CREATE INDEX idx_diagnosticos_animal ON diagnosticos_gestacao(animal_id);
CREATE INDEX idx_eventos_animal ON eventos_sanitarios(animal_id);
CREATE INDEX idx_financeiro_fazenda ON financeiro(fazenda_id);
CREATE INDEX idx_financeiro_data ON financeiro(data_lancamento);
