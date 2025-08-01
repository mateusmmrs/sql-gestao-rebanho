"""
Gerador de dados de exemplo pra testar as queries.
Popula o schema com dados realistas de uma operação de 3 fazendas.
"""
import random
from datetime import date, timedelta

random.seed(42)

RACAS = ['Nelore', 'Angus', 'Nelore x Angus (F1)', 'Brahman', 'Senepol']
VACINAS = [
    ('Febre Aftosa', 182), ('Brucelose', 365), ('Raiva', 365),
    ('Clostridiose', 180), ('Leptospirose', 365),
]
CUSTOS_SAT = {'vacinacao': 8.50, 'vermifugacao': 12.00, 'tratamento': 85.00, 'exame': 25.00}

def d(y, m, day=1):
    return f"'{y}-{m:02d}-{day:02d}'"

f = open('/home/mateus/.gemini/antigravity/scratch/codexor/sql-gestao-rebanho/seed_data.sql', 'w')

f.write("-- ============================================================\n")
f.write("-- DADOS DE EXEMPLO — Gerados para validar as queries\n")
f.write("-- 3 fazendas, ~800 animais, 4 estações de monta\n")
f.write("-- ============================================================\n\n")

# Fazendas
fazendas = [
    (1, 'Fazenda Santa Maria', 'MT', 'Sinop', 2400, 'semi-intensivo', 3600),
    (2, 'Fazenda Boa Vista', 'GO', 'Rio Verde', 1200, 'intensivo', 2400),
    (3, 'Fazenda Três Rios', 'MS', 'Naviraí', 1800, 'semi-intensivo', 2700),
]
f.write("-- FAZENDAS\n")
for faz in fazendas:
    f.write(f"INSERT INTO fazendas (id, nome, uf, municipio, area_ha, sistema, capacidade_ua) VALUES ({faz[0]}, '{faz[1]}', '{faz[2]}', '{faz[3]}', {faz[4]}, '{faz[5]}', {faz[6]});\n")

# Lotes
lotes = [
    (1, 1, 'Cria - Pasto 1', 'cria', 'Pasto A1', 300),
    (2, 1, 'Recria - Pasto 2', 'recria', 'Pasto A2', 400),
    (3, 1, 'Engorda - Pasto 3', 'engorda', 'Pasto A3', 350),
    (4, 1, 'Matrizes - Reproducao', 'reproducao', 'Pasto A4', 500),
    (5, 2, 'Cria - BV', 'cria', 'Pasto B1', 200),
    (6, 2, 'Engorda - BV', 'engorda', 'Pasto B2', 300),
    (7, 2, 'Matrizes - BV', 'reproducao', 'Pasto B3', 350),
    (8, 3, 'Cria - TR', 'cria', 'Pasto C1', 250),
    (9, 3, 'Recria - TR', 'recria', 'Pasto C2', 350),
    (10, 3, 'Engorda - TR', 'engorda', 'Pasto C3', 300),
    (11, 3, 'Matrizes - TR', 'reproducao', 'Pasto C4', 400),
]
f.write("\n-- LOTES\n")
for lot in lotes:
    f.write(f"INSERT INTO lotes (id, fazenda_id, nome, tipo, pasto, area_ha) VALUES ({lot[0]}, {lot[1]}, '{lot[2]}', '{lot[3]}', '{lot[4]}', {lot[5]});\n")

# Animais — touros
f.write("\n-- TOUROS\n")
touros_data = []
animal_id = 1
for faz_id in [1, 2, 3]:
    for i in range(5):
        brinco = f"T{faz_id}{i+1:03d}"
        raca = random.choice(['Nelore', 'Angus', 'Brahman'])
        nasc = date(2018 - random.randint(0, 4), random.randint(1, 12), random.randint(1, 28))
        lote_rep = [l[0] for l in lotes if l[1] == faz_id and l[3] == 'reproducao'][0]
        f.write(f"INSERT INTO animais (id, brinco, sexo, raca, data_nascimento, fazenda_id, lote_id, categoria, status, data_entrada) VALUES ({animal_id}, '{brinco}', 'M', '{raca}', '{nasc}', {faz_id}, {lote_rep}, 'touro', 'ativo', '{nasc + timedelta(days=730)}');\n")
        dep_d = round(random.uniform(5, 25), 2)
        dep_s = round(random.uniform(8, 35), 2)
        dep_pe = round(random.uniform(0.5, 3.0), 2)
        dep_f = round(random.uniform(-1, 4), 2)
        preco = round(random.uniform(15000, 80000), 2)
        touros_data.append((animal_id, brinco, faz_id))
        f.write(f"INSERT INTO touros (animal_id, dep_peso_desmama, dep_peso_sobreano, dep_perimetro_escrotal, dep_fertilidade, preco_aquisicao, data_aquisicao) VALUES ({animal_id}, {dep_d}, {dep_s}, {dep_pe}, {dep_f}, {preco}, '{nasc + timedelta(days=730)}');\n")
        animal_id += 1

# Vacas
f.write("\n-- VACAS\n")
vacas_data = []
for faz_id in [1, 2, 3]:
    n_vacas = {1: 250, 2: 150, 3: 200}[faz_id]
    lote_rep = [l[0] for l in lotes if l[1] == faz_id and l[3] == 'reproducao'][0]
    for i in range(n_vacas):
        brinco = f"V{faz_id}{i+1:04d}"
        raca = random.choice(RACAS)
        nasc = date(2016 - random.randint(0, 8), random.randint(1, 12), min(random.randint(1, 28), 28))
        status = random.choices(['ativo', 'descartado', 'morto'], weights=[85, 12, 3])[0]
        saida = None
        motivo = None
        if status == 'descartado':
            saida = date(2025, random.randint(1, 12), random.randint(1, 28))
            motivo = random.choice(['falha reprodutiva', 'idade avançada', 'problema locomotor', 'mastite'])
        elif status == 'morto':
            saida = date(2025, random.randint(1, 12), random.randint(1, 28))
            motivo = random.choice(['acidente', 'doença', 'parto distócico'])
        saida_str = f"'{saida}'" if saida else 'NULL'
        motivo_str = f"'{motivo}'" if motivo else 'NULL'
        f.write(f"INSERT INTO animais (id, brinco, sexo, raca, data_nascimento, fazenda_id, lote_id, categoria, status, data_entrada, data_saida, motivo_saida) VALUES ({animal_id}, '{brinco}', 'F', '{raca}', '{nasc}', {faz_id}, {lote_rep}, 'vaca', '{status}', '{nasc + timedelta(days=730)}', {saida_str}, {motivo_str});\n")
        vacas_data.append((animal_id, brinco, faz_id, status))
        animal_id += 1

# Bezerros e novilhos
f.write("\n-- BEZERROS E NOVILHOS\n")
bezerros_data = []
for faz_id in [1, 2, 3]:
    n_jovens = {1: 80, 2: 50, 3: 60}[faz_id]
    lotes_faz = [l for l in lotes if l[1] == faz_id]
    for i in range(n_jovens):
        sexo = random.choice(['M', 'F'])
        cat = 'bezerro' if sexo == 'M' else 'bezerra'
        if random.random() > 0.5:
            cat = 'novilho' if sexo == 'M' else 'novilha'
        brinco = f"J{faz_id}{i+1:04d}"
        raca = random.choice(RACAS)
        nasc = date(2024 - random.randint(0, 2), random.randint(1, 12), min(random.randint(1, 28), 28))
        tipo_lote = 'cria' if cat in ['bezerro', 'bezerra'] else 'recria'
        lote_opts = [l[0] for l in lotes_faz if l[3] == tipo_lote]
        lote_id = lote_opts[0] if lote_opts else lotes_faz[0][0]
        f.write(f"INSERT INTO animais (id, brinco, sexo, raca, data_nascimento, fazenda_id, lote_id, categoria, status, data_entrada) VALUES ({animal_id}, '{brinco}', '{sexo}', '{raca}', '{nasc}', {faz_id}, {lote_id}, '{cat}', 'ativo', '{nasc}');\n")
        bezerros_data.append((animal_id, brinco, faz_id, nasc))
        animal_id += 1

# Bois de engorda
f.write("\n-- BOIS DE ENGORDA\n")
bois_data = []
for faz_id in [1, 2, 3]:
    n_bois = {1: 60, 2: 40, 3: 50}[faz_id]
    lote_eng = [l[0] for l in lotes if l[1] == faz_id and l[3] == 'engorda'][0]
    for i in range(n_bois):
        brinco = f"B{faz_id}{i+1:04d}"
        raca = random.choice(RACAS)
        nasc = date(2022 - random.randint(0, 1), random.randint(1, 12), min(random.randint(1, 28), 28))
        status = random.choices(['ativo', 'vendido'], weights=[70, 30])[0]
        saida = f"'{date(2025, random.randint(6, 12), random.randint(1, 28))}'" if status == 'vendido' else 'NULL'
        f.write(f"INSERT INTO animais (id, brinco, sexo, raca, data_nascimento, fazenda_id, lote_id, categoria, status, data_entrada, data_saida) VALUES ({animal_id}, '{brinco}', 'M', '{raca}', '{nasc}', {faz_id}, {lote_eng}, 'boi', '{status}', '{nasc + timedelta(days=365)}', {saida});\n")
        bois_data.append((animal_id, brinco, faz_id, status))
        animal_id += 1

# Estações de monta
f.write("\n-- ESTAÇÕES DE MONTA\n")
estacao_id = 1
for faz_id in [1, 2, 3]:
    for ano in [2022, 2023, 2024, 2025]:
        protocolo = random.choice(['IATF', 'IATF+repasse', 'monta_natural'])
        f.write(f"INSERT INTO estacoes_monta (id, fazenda_id, ano, data_inicio, data_fim, protocolo) VALUES ({estacao_id}, {faz_id}, {ano}, '{ano}-10-01', '{ano+1}-01-31', '{protocolo}');\n")
        estacao_id += 1

# Diagnósticos de gestação
f.write("\n-- DIAGNÓSTICOS DE GESTAÇÃO\n")
diag_id = 1
touro_counter = {faz: [t[0] for t in touros_data if t[2] == faz] for faz in [1, 2, 3]}
for vaca_id, brinco, faz_id, status in vacas_data:
    if status == 'morto':
        continue
    for estacao in range(1, estacao_id):
        # Só estações da mesma fazenda
        est_faz = (estacao - 1) // 4 + 1
        if est_faz != faz_id:
            continue
        if random.random() > 0.8:
            continue  # Nem toda vaca é diagnosticada toda estação

        resultado = random.choices(['prenhe', 'vazia', 'perda'], weights=[72, 23, 5])[0]
        ecc = round(random.uniform(3.5, 8.0), 1)
        touro = random.choice(touro_counter[faz_id])
        ano = 2022 + (estacao - 1) % 4
        data_diag = date(ano + 1, random.randint(2, 4), min(random.randint(1, 28), 28))
        dias_gest = random.randint(30, 120) if resultado == 'prenhe' else 0

        f.write(f"INSERT INTO diagnosticos_gestacao (id, animal_id, estacao_id, data_diagnostico, resultado, dias_gestacao, touro_id, ecc) VALUES ({diag_id}, {vaca_id}, {estacao}, '{data_diag}', '{resultado}', {dias_gest}, (SELECT id FROM touros WHERE animal_id = {touro}), {ecc});\n")
        diag_id += 1

# Pesagens
f.write("\n-- PESAGENS\n")
pes_id = 1
all_animals = [(a[0], a[2]) for a in vacas_data if a[3] == 'ativo'] + \
              [(b[0], b[2]) for b in bois_data if b[3] == 'ativo'] + \
              [(j[0], j[2]) for j in bezerros_data]

for aid, faz_id in all_animals:
    # 2-4 pesagens por animal
    for _ in range(random.randint(2, 4)):
        data_p = date(2024 + random.randint(0, 1), random.randint(1, 12), min(random.randint(1, 28), 28))
        peso = round(random.uniform(180, 580), 1)
        tipo = random.choice(['rotina', 'rotina', 'rotina', 'desmama', 'sobreano'])
        lote_id = random.choice([l[0] for l in lotes if l[1] == faz_id])
        f.write(f"INSERT INTO pesagens (id, animal_id, data_pesagem, peso_kg, tipo, lote_id) VALUES ({pes_id}, {aid}, '{data_p}', {peso}, '{tipo}', {lote_id});\n")
        pes_id += 1

# Eventos sanitários
f.write("\n-- EVENTOS SANITÁRIOS\n")
ev_id = 1
for aid, faz_id in random.sample(all_animals, min(400, len(all_animals))):
    for _ in range(random.randint(1, 3)):
        tipo = random.choice(['vacinacao', 'vacinacao', 'vermifugacao', 'tratamento'])
        vacina_nome, intervalo = random.choice(VACINAS) if tipo == 'vacinacao' else ('Ivermectina', 90)
        data_ev = date(2025, random.randint(1, 12), min(random.randint(1, 28), 28))
        prox = data_ev + timedelta(days=intervalo)
        custo = CUSTOS_SAT.get(tipo, 10.0)
        f.write(f"INSERT INTO eventos_sanitarios (id, animal_id, data_evento, tipo, descricao, produto, custo, proxima_dose) VALUES ({ev_id}, {aid}, '{data_ev}', '{tipo}', '{vacina_nome}', '{vacina_nome}', {custo}, '{prox}');\n")
        ev_id += 1

# Financeiro
f.write("\n-- FINANCEIRO\n")
fin_id = 1
categorias_desp = ['nutricao', 'sanidade', 'mao_de_obra', 'manutencao', 'combustivel', 'insumos']
for faz_id in [1, 2, 3]:
    for mes in range(1, 13):
        # Despesas mensais
        for cat in categorias_desp:
            valor = round(random.uniform(5000, 45000), 2)
            f.write(f"INSERT INTO financeiro (id, fazenda_id, data_lancamento, tipo, categoria, valor) VALUES ({fin_id}, {faz_id}, '2025-{mes:02d}-15', 'despesa', '{cat}', {valor});\n")
            fin_id += 1
        # Receita de venda (trimestral)
        if mes % 3 == 0:
            valor_rec = round(random.uniform(80000, 350000), 2)
            f.write(f"INSERT INTO financeiro (id, fazenda_id, data_lancamento, tipo, categoria, valor) VALUES ({fin_id}, {faz_id}, '2025-{mes:02d}-20', 'receita', 'venda_gado', {valor_rec});\n")
            fin_id += 1

f.write(f"\n-- Total: {animal_id-1} animais, {diag_id-1} diagnósticos, {pes_id-1} pesagens, {ev_id-1} eventos sanitários, {fin_id-1} lançamentos financeiros\n")
f.close()

print(f"✅ Seed data gerado!")
print(f"   {animal_id-1} animais")
print(f"   {diag_id-1} diagnósticos de gestação")
print(f"   {pes_id-1} pesagens")
print(f"   {ev_id-1} eventos sanitários")
print(f"   {fin_id-1} lançamentos financeiros")
