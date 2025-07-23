-- ============================================================
-- QUERIES ESTRATÉGICAS PARA GESTÃO DE REBANHO
-- 
-- 20 queries organizadas por área de negócio.
-- Cada query resolve um problema real de gestão pecuária.
-- ============================================================


-- ============================================================
-- REPRODUÇÃO (Queries 1-5)
-- ============================================================

-- QUERY 1: Vacas que falharam 2+ estações consecutivas (candidatas a descarte)
-- Por que importa: falha reprodutiva consecutiva é o principal critério
-- de descarte. Identificar essas vacas economiza custo de manutenção.

WITH falhas_por_estacao AS (
    SELECT
        a.id,
        a.brinco,
        a.raca,
        em.ano,
        dg.resultado,
        ROW_NUMBER() OVER (PARTITION BY a.id ORDER BY em.ano) AS seq,
        LAG(dg.resultado) OVER (PARTITION BY a.id ORDER BY em.ano) AS resultado_anterior
    FROM animais a
    JOIN diagnosticos_gestacao dg ON dg.animal_id = a.id
    JOIN estacoes_monta em ON em.id = dg.estacao_id
    WHERE a.categoria = 'vaca'
      AND a.status = 'ativo'
)
SELECT
    brinco,
    raca,
    ano AS ultima_estacao,
    'Falhou 2+ estações consecutivas' AS alerta
FROM falhas_por_estacao
WHERE resultado = 'vazia'
  AND resultado_anterior = 'vazia'
ORDER BY ano DESC;


-- QUERY 2: Taxa de prenhez por fazenda, raça e estação
-- Por que importa: KPI principal da reprodução. Permite comparar
-- performance entre fazendas e identificar problemas.

SELECT
    f.nome AS fazenda,
    a.raca,
    em.ano,
    COUNT(*) AS total_diagnosticadas,
    SUM(CASE WHEN dg.resultado = 'prenhe' THEN 1 ELSE 0 END) AS prenhes,
    ROUND(
        SUM(CASE WHEN dg.resultado = 'prenhe' THEN 1 ELSE 0 END)::NUMERIC
        / COUNT(*) * 100, 1
    ) AS taxa_prenhez_pct
FROM diagnosticos_gestacao dg
JOIN animais a ON a.id = dg.animal_id
JOIN estacoes_monta em ON em.id = dg.estacao_id
JOIN fazendas f ON f.id = em.fazenda_id
GROUP BY f.nome, a.raca, em.ano
ORDER BY em.ano DESC, taxa_prenhez_pct DESC;


-- QUERY 3: Performance reprodutiva por touro (custo-benefício)
-- Por que importa: touros caros não necessariamente dão resultado.
-- Essa query cruza DEPs, preço pago e taxa de prenhez real.

SELECT
    a.brinco AS touro_brinco,
    a.raca,
    t.dep_peso_desmama,
    t.preco_aquisicao,
    COUNT(dg.id) AS total_coberturas,
    SUM(CASE WHEN dg.resultado = 'prenhe' THEN 1 ELSE 0 END) AS prenhes,
    ROUND(
        SUM(CASE WHEN dg.resultado = 'prenhe' THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(dg.id), 0) * 100, 1
    ) AS taxa_prenhez_pct,
    ROUND(
        t.preco_aquisicao / NULLIF(SUM(CASE WHEN dg.resultado = 'prenhe' THEN 1 ELSE 0 END), 0), 2
    ) AS custo_por_prenhez
FROM touros t
JOIN animais a ON a.id = t.animal_id
LEFT JOIN diagnosticos_gestacao dg ON dg.touro_id = t.id
GROUP BY a.brinco, a.raca, t.dep_peso_desmama, t.preco_aquisicao
ORDER BY taxa_prenhez_pct DESC;


-- QUERY 4: Vacas com ECC abaixo de 5 na última avaliação (risco reprodutivo)
-- Por que importa: ECC baixo = vaca magra = falha reprodutiva provável.
-- Precisa de intervenção nutricional antes da estação de monta.

SELECT
    a.brinco,
    a.raca,
    f.nome AS fazenda,
    l.nome AS lote,
    dg.ecc AS ultimo_ecc,
    dg.data_diagnostico,
    dg.resultado AS ultimo_resultado
FROM animais a
JOIN diagnosticos_gestacao dg ON dg.animal_id = a.id
JOIN fazendas f ON f.id = a.fazenda_id
LEFT JOIN lotes l ON l.id = a.lote_id
WHERE a.status = 'ativo'
  AND a.categoria = 'vaca'
  AND dg.ecc < 5.0
  AND dg.data_diagnostico = (
      SELECT MAX(dg2.data_diagnostico)
      FROM diagnosticos_gestacao dg2
      WHERE dg2.animal_id = a.id
  )
ORDER BY dg.ecc ASC;


-- QUERY 5: Intervalo entre partos (IEP) por vaca
-- Por que importa: IEP ideal < 365 dias. Vacas com IEP alto estão
-- perdendo ciclos reprodutivos e custando mais do que produzem.

SELECT
    a.brinco,
    a.raca,
    COUNT(p.id) AS total_partos,
    MIN(p.data_parto) AS primeiro_parto,
    MAX(p.data_parto) AS ultimo_parto,
    ROUND(
        AVG(p.data_parto - LAG(p.data_parto) OVER (PARTITION BY a.id ORDER BY p.data_parto))
    , 0) AS iep_medio_dias
FROM animais a
JOIN partos p ON p.mae_id = a.id
WHERE a.categoria = 'vaca'
GROUP BY a.id, a.brinco, a.raca
HAVING COUNT(p.id) >= 2
ORDER BY iep_medio_dias DESC;


-- ============================================================
-- DESEMPENHO E PESAGENS (Queries 6-10)
-- ============================================================

-- QUERY 6: GMD (Ganho Médio Diário) por lote nos últimos 90 dias
-- Por que importa: o GMD indica se o lote está ganhando peso conforme
-- esperado. Queda no GMD pode indicar problema nutricional ou sanitário.

WITH pesagens_recentes AS (
    SELECT
        p.animal_id,
        p.peso_kg,
        p.data_pesagem,
        p.lote_id,
        LAG(p.peso_kg) OVER (PARTITION BY p.animal_id ORDER BY p.data_pesagem) AS peso_anterior,
        LAG(p.data_pesagem) OVER (PARTITION BY p.animal_id ORDER BY p.data_pesagem) AS data_anterior
    FROM pesagens p
    WHERE p.data_pesagem >= CURRENT_DATE - INTERVAL '90 days'
)
SELECT
    l.nome AS lote,
    f.nome AS fazenda,
    COUNT(DISTINCT pr.animal_id) AS animais,
    ROUND(AVG(
        (pr.peso_kg - pr.peso_anterior) / NULLIF((pr.data_pesagem - pr.data_anterior), 0)
    ), 3) AS gmd_kg_dia,
    ROUND(AVG(pr.peso_kg), 1) AS peso_medio_atual
FROM pesagens_recentes pr
JOIN lotes l ON l.id = pr.lote_id
JOIN fazendas f ON f.id = l.fazenda_id
WHERE pr.peso_anterior IS NOT NULL
  AND pr.data_anterior IS NOT NULL
GROUP BY l.nome, f.nome
ORDER BY gmd_kg_dia DESC;


-- QUERY 7: Animais sem pesagem nos últimos 60 dias (alerta de manejo)
-- Por que importa: animal sem pesagem recente pode estar "perdido" no
-- pasto ou com problema. Sinaliza falha de manejo.

SELECT
    a.brinco,
    a.raca,
    a.categoria,
    f.nome AS fazenda,
    l.nome AS lote,
    MAX(p.data_pesagem) AS ultima_pesagem,
    CURRENT_DATE - MAX(p.data_pesagem) AS dias_sem_pesar
FROM animais a
JOIN fazendas f ON f.id = a.fazenda_id
LEFT JOIN lotes l ON l.id = a.lote_id
LEFT JOIN pesagens p ON p.animal_id = a.id
WHERE a.status = 'ativo'
GROUP BY a.id, a.brinco, a.raca, a.categoria, f.nome, l.nome
HAVING MAX(p.data_pesagem) < CURRENT_DATE - INTERVAL '60 days'
    OR MAX(p.data_pesagem) IS NULL
ORDER BY dias_sem_pesar DESC NULLS FIRST;


-- QUERY 8: Previsão de lotes prontos para abate no próximo mês
-- Por que importa: planejamento de embarque e negociação com frigorífico.
-- Peso de abate referência: 540 kg (18 arrobas).

SELECT
    l.nome AS lote,
    f.nome AS fazenda,
    COUNT(*) AS animais_no_lote,
    ROUND(AVG(ult.peso_kg), 1) AS peso_medio_kg,
    ROUND(AVG(ult.peso_kg) / 30, 1) AS arrobas_media,
    SUM(CASE WHEN ult.peso_kg >= 510 THEN 1 ELSE 0 END) AS prontos_agora,
    SUM(CASE WHEN ult.peso_kg BETWEEN 480 AND 509 THEN 1 ELSE 0 END) AS prontos_30_dias
FROM lotes l
JOIN fazendas f ON f.id = l.fazenda_id
JOIN animais a ON a.lote_id = l.id AND a.status = 'ativo'
JOIN LATERAL (
    SELECT peso_kg
    FROM pesagens
    WHERE animal_id = a.id
    ORDER BY data_pesagem DESC
    LIMIT 1
) ult ON TRUE
WHERE l.tipo = 'engorda'
GROUP BY l.nome, f.nome
HAVING AVG(ult.peso_kg) >= 450
ORDER BY peso_medio_kg DESC;


-- QUERY 9: Ranking de peso à desmama por touro (genética)
-- Por que importa: peso de desmama reflete genética materna + paterna.
-- Permite avaliar se o investimento no touro está retornando em kg.

SELECT
    t_animal.brinco AS touro,
    t_animal.raca,
    t.dep_peso_desmama,
    COUNT(p_desm.id) AS bezerros_pesados,
    ROUND(AVG(p_desm.peso_kg), 1) AS peso_desmama_medio,
    ROUND(MIN(p_desm.peso_kg), 1) AS peso_min,
    ROUND(MAX(p_desm.peso_kg), 1) AS peso_max,
    ROUND(STDDEV(p_desm.peso_kg), 1) AS desvio_padrao
FROM touros t
JOIN animais t_animal ON t_animal.id = t.animal_id
JOIN diagnosticos_gestacao dg ON dg.touro_id = t.id AND dg.resultado = 'prenhe'
JOIN partos pa ON pa.mae_id = dg.animal_id
JOIN pesagens p_desm ON p_desm.animal_id = pa.bezerro_id AND p_desm.tipo = 'desmama'
GROUP BY t_animal.brinco, t_animal.raca, t.dep_peso_desmama
HAVING COUNT(p_desm.id) >= 5
ORDER BY peso_desmama_medio DESC;


-- QUERY 10: Curva de crescimento por raça (peso médio por idade)
-- Por que importa: permite comparar se uma raça está performando
-- conforme o esperado para a idade.

SELECT
    a.raca,
    CASE
        WHEN AGE(p.data_pesagem, a.data_nascimento) < INTERVAL '8 months' THEN '0-8m (cria)'
        WHEN AGE(p.data_pesagem, a.data_nascimento) < INTERVAL '14 months' THEN '8-14m (recria)'
        WHEN AGE(p.data_pesagem, a.data_nascimento) < INTERVAL '24 months' THEN '14-24m (engorda)'
        ELSE '24m+ (terminação)'
    END AS faixa_etaria,
    COUNT(*) AS pesagens,
    ROUND(AVG(p.peso_kg), 1) AS peso_medio,
    ROUND(MIN(p.peso_kg), 1) AS peso_min,
    ROUND(MAX(p.peso_kg), 1) AS peso_max
FROM pesagens p
JOIN animais a ON a.id = p.animal_id
WHERE a.data_nascimento IS NOT NULL
GROUP BY a.raca, faixa_etaria
ORDER BY a.raca, faixa_etaria;


-- ============================================================
-- SANIDADE (Queries 11-13)
-- ============================================================

-- QUERY 11: Custo sanitário por cabeça por fazenda
-- Por que importa: custo sanitário alto pode indicar problema
-- ambiental, manejo inadequado ou surto que precisa de atenção.

SELECT
    f.nome AS fazenda,
    COUNT(DISTINCT a.id) AS total_animais,
    COUNT(es.id) AS total_eventos,
    ROUND(SUM(COALESCE(es.custo, 0)), 2) AS custo_sanitario_total,
    ROUND(SUM(COALESCE(es.custo, 0)) / NULLIF(COUNT(DISTINCT a.id), 0), 2) AS custo_por_cabeca,
    STRING_AGG(DISTINCT es.tipo, ', ') AS tipos_evento
FROM fazendas f
JOIN animais a ON a.fazenda_id = f.id AND a.status = 'ativo'
LEFT JOIN eventos_sanitarios es ON es.animal_id = a.id
    AND es.data_evento >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY f.nome
ORDER BY custo_por_cabeca DESC;


-- QUERY 12: Animais com vacina vencida ou próxima do vencimento
-- Por que importa: atraso vacinal pode gerar multa, impedir GTA
-- (Guia de Trânsito Animal) e causar surtos.

SELECT
    a.brinco,
    a.categoria,
    f.nome AS fazenda,
    es.descricao AS vacina,
    es.data_evento AS data_aplicacao,
    es.proxima_dose,
    CASE
        WHEN es.proxima_dose < CURRENT_DATE THEN 'VENCIDA'
        WHEN es.proxima_dose < CURRENT_DATE + INTERVAL '15 days' THEN 'VENCE EM 15 DIAS'
        WHEN es.proxima_dose < CURRENT_DATE + INTERVAL '30 days' THEN 'VENCE EM 30 DIAS'
    END AS status_vacina
FROM eventos_sanitarios es
JOIN animais a ON a.id = es.animal_id
JOIN fazendas f ON f.id = a.fazenda_id
WHERE es.tipo = 'vacinacao'
  AND a.status = 'ativo'
  AND es.proxima_dose < CURRENT_DATE + INTERVAL '30 days'
  AND es.data_evento = (
      SELECT MAX(es2.data_evento)
      FROM eventos_sanitarios es2
      WHERE es2.animal_id = a.id
        AND es2.descricao = es.descricao
  )
ORDER BY es.proxima_dose ASC;


-- QUERY 13: Taxa de mortalidade por fazenda e categoria (últimos 12 meses)
-- Por que importa: mortalidade acima de 3% em bezerros ou 1% em adultos
-- indica problema grave de manejo.

SELECT
    f.nome AS fazenda,
    a.categoria,
    COUNT(*) FILTER (WHERE a.status = 'morto'
        AND a.data_saida >= CURRENT_DATE - INTERVAL '12 months') AS mortes,
    COUNT(*) AS total_no_periodo,
    ROUND(
        COUNT(*) FILTER (WHERE a.status = 'morto'
            AND a.data_saida >= CURRENT_DATE - INTERVAL '12 months')::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    ) AS taxa_mortalidade_pct,
    CASE
        WHEN a.categoria IN ('bezerro','bezerra')
            AND COUNT(*) FILTER (WHERE a.status = 'morto') > COUNT(*) * 0.03
            THEN '⚠️ ACIMA DO ACEITÁVEL (>3%)'
        WHEN a.categoria IN ('vaca','boi','touro')
            AND COUNT(*) FILTER (WHERE a.status = 'morto') > COUNT(*) * 0.01
            THEN '⚠️ ACIMA DO ACEITÁVEL (>1%)'
        ELSE '✅ Normal'
    END AS status_alerta
FROM animais a
JOIN fazendas f ON f.id = a.fazenda_id
GROUP BY f.nome, a.categoria
HAVING COUNT(*) FILTER (WHERE a.status = 'morto') > 0
ORDER BY taxa_mortalidade_pct DESC;


-- ============================================================
-- FINANCEIRO E GESTÃO (Queries 14-17)
-- ============================================================

-- QUERY 14: Resultado financeiro por fazenda (receita - despesa) últimos 12 meses
-- Por que importa: visão consolidada de qual fazenda está dando lucro.

SELECT
    f.nome AS fazenda,
    f.uf,
    SUM(CASE WHEN fin.tipo = 'receita' THEN fin.valor ELSE 0 END) AS receita_total,
    SUM(CASE WHEN fin.tipo = 'despesa' THEN fin.valor ELSE 0 END) AS despesa_total,
    SUM(CASE WHEN fin.tipo = 'receita' THEN fin.valor ELSE -fin.valor END) AS resultado,
    ROUND(
        SUM(CASE WHEN fin.tipo = 'receita' THEN fin.valor ELSE -fin.valor END)
        / NULLIF(f.area_ha, 0), 2
    ) AS resultado_por_ha
FROM financeiro fin
JOIN fazendas f ON f.id = fin.fazenda_id
WHERE fin.data_lancamento >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY f.nome, f.uf, f.area_ha
ORDER BY resultado DESC;


-- QUERY 15: Custo por arroba produzida por lote de engorda
-- Por que importa: o custo por arroba define se a operação é viável.
-- Se o custo supera o preço de mercado, está no prejuízo.

WITH peso_entrada_saida AS (
    SELECT
        m.animal_id,
        MAX(CASE WHEN m.tipo = 'entrada' THEN m.peso_kg END) AS peso_entrada,
        MAX(CASE WHEN m.tipo IN ('venda','saida') THEN m.peso_kg END) AS peso_saida,
        MAX(CASE WHEN m.tipo IN ('venda','saida') THEN m.valor END) AS valor_venda,
        m.lote_destino_id AS lote_id
    FROM movimentacoes m
    GROUP BY m.animal_id, m.lote_destino_id
)
SELECT
    l.nome AS lote,
    COUNT(*) AS animais_vendidos,
    ROUND(AVG(pes.peso_saida - pes.peso_entrada), 1) AS ganho_medio_kg,
    ROUND(AVG(pes.peso_saida - pes.peso_entrada) / 30, 1) AS arrobas_produzidas,
    ROUND(SUM(COALESCE(fin.valor, 0)) / NULLIF(COUNT(*), 0), 2) AS custo_medio_animal,
    ROUND(
        SUM(COALESCE(fin.valor, 0))
        / NULLIF(SUM((pes.peso_saida - pes.peso_entrada) / 30), 0), 2
    ) AS custo_por_arroba
FROM peso_entrada_saida pes
JOIN lotes l ON l.id = pes.lote_id
LEFT JOIN financeiro fin ON fin.lote_id = l.id AND fin.tipo = 'despesa'
WHERE pes.peso_saida IS NOT NULL
GROUP BY l.nome
ORDER BY custo_por_arroba ASC;


-- QUERY 16: Lotação atual por fazenda (UA/ha)
-- Por que importa: lotação acima da capacidade degrada o pasto.
-- Abaixo significa que está subutilizando a terra.

WITH peso_atual AS (
    SELECT DISTINCT ON (a.id)
        a.id,
        a.fazenda_id,
        p.peso_kg,
        CASE
            WHEN a.categoria IN ('bezerro','bezerra') THEN 0.4
            WHEN a.categoria IN ('novilho','novilha') THEN 0.7
            ELSE 1.0
        END AS fator_ua
    FROM animais a
    LEFT JOIN pesagens p ON p.animal_id = a.id
    WHERE a.status = 'ativo'
    ORDER BY a.id, p.data_pesagem DESC
)
SELECT
    f.nome AS fazenda,
    f.area_ha,
    f.capacidade_ua,
    COUNT(*) AS total_cabecas,
    ROUND(SUM(pa.fator_ua), 1) AS ua_total,
    ROUND(SUM(pa.fator_ua) / NULLIF(f.area_ha, 0), 2) AS ua_por_ha,
    ROUND(SUM(pa.fator_ua) / NULLIF(f.capacidade_ua, 0) * 100, 1) AS ocupacao_pct,
    CASE
        WHEN SUM(pa.fator_ua) / NULLIF(f.capacidade_ua, 0) > 1.0 THEN '⚠️ SUPERLOTAÇÃO'
        WHEN SUM(pa.fator_ua) / NULLIF(f.capacidade_ua, 0) < 0.5 THEN 'ℹ️ Subutilizado'
        ELSE '✅ Adequado'
    END AS status
FROM peso_atual pa
JOIN fazendas f ON f.id = pa.fazenda_id
GROUP BY f.nome, f.area_ha, f.capacidade_ua
ORDER BY ua_por_ha DESC;


-- QUERY 17: Ranking de fazendas por eficiência reprodutiva
-- Por que importa: visão executiva pra comparar as fazendas e
-- decidir onde investir mais em reprodução.

SELECT
    f.nome AS fazenda,
    f.uf,
    COUNT(DISTINCT a.id) AS total_matrizes,
    ROUND(
        COUNT(*) FILTER (WHERE dg.resultado = 'prenhe')::NUMERIC
        / NULLIF(COUNT(dg.id), 0) * 100, 1
    ) AS taxa_prenhez_pct,
    ROUND(AVG(dg.ecc), 1) AS ecc_medio,
    COUNT(DISTINCT dg.touro_id) AS touros_utilizados,
    RANK() OVER (ORDER BY
        COUNT(*) FILTER (WHERE dg.resultado = 'prenhe')::NUMERIC
        / NULLIF(COUNT(dg.id), 0) DESC
    ) AS ranking
FROM fazendas f
JOIN animais a ON a.fazenda_id = f.id AND a.categoria = 'vaca'
JOIN diagnosticos_gestacao dg ON dg.animal_id = a.id
GROUP BY f.nome, f.uf
ORDER BY ranking;


-- ============================================================
-- VIEWS PARA DASHBOARD (Queries 18-20)
-- ============================================================

-- QUERY 18: View — KPIs consolidados por fazenda
-- Útil pra alimentar um dashboard com indicadores gerais.

CREATE OR REPLACE VIEW vw_kpis_fazenda AS
SELECT
    f.id AS fazenda_id,
    f.nome,
    f.uf,
    COUNT(DISTINCT a.id) FILTER (WHERE a.status = 'ativo') AS animais_ativos,
    COUNT(DISTINCT a.id) FILTER (WHERE a.categoria = 'vaca' AND a.status = 'ativo') AS matrizes,
    COUNT(DISTINCT a.id) FILTER (WHERE a.categoria = 'touro' AND a.status = 'ativo') AS touros_ativos,
    COUNT(DISTINCT a.id) FILTER (WHERE a.status = 'morto'
        AND a.data_saida >= CURRENT_DATE - INTERVAL '12 months') AS mortes_12m,
    ROUND(f.area_ha, 0) AS area_ha
FROM fazendas f
LEFT JOIN animais a ON a.fazenda_id = f.id
GROUP BY f.id, f.nome, f.uf, f.area_ha;


-- QUERY 19: View — Histórico reprodutivo por vaca
-- Útil pra montar ficha individual da vaca.

CREATE OR REPLACE VIEW vw_historico_reprodutivo AS
SELECT
    a.brinco,
    a.raca,
    f.nome AS fazenda,
    em.ano AS estacao,
    em.protocolo,
    dg.resultado,
    dg.ecc,
    dg.data_diagnostico,
    t_animal.brinco AS touro_brinco,
    p.data_parto,
    p.peso_nascimento,
    p.tipo_parto
FROM animais a
JOIN fazendas f ON f.id = a.fazenda_id
LEFT JOIN diagnosticos_gestacao dg ON dg.animal_id = a.id
LEFT JOIN estacoes_monta em ON em.id = dg.estacao_id
LEFT JOIN touros t ON t.id = dg.touro_id
LEFT JOIN animais t_animal ON t_animal.id = t.animal_id
LEFT JOIN partos p ON p.mae_id = a.id AND p.estacao_id = em.id
WHERE a.categoria = 'vaca'
ORDER BY a.brinco, em.ano;


-- QUERY 20: View — Animais em risco (consolidado de alertas)
-- Combina vários critérios pra gerar uma lista de atenção diária.

CREATE OR REPLACE VIEW vw_alertas_rebanho AS

-- Vacas com ECC baixo
SELECT a.brinco, 'ECC baixo (<5)' AS alerta, f.nome AS fazenda,
       'Risco reprodutivo' AS urgencia
FROM animais a
JOIN fazendas f ON f.id = a.fazenda_id
JOIN diagnosticos_gestacao dg ON dg.animal_id = a.id
WHERE a.status = 'ativo' AND dg.ecc < 5.0
  AND dg.data_diagnostico = (SELECT MAX(d2.data_diagnostico) FROM diagnosticos_gestacao d2 WHERE d2.animal_id = a.id)

UNION ALL

-- Animais sem pesagem em 60+ dias
SELECT a.brinco, 'Sem pesagem 60+ dias' AS alerta, f.nome AS fazenda,
       'Manejo' AS urgencia
FROM animais a
JOIN fazendas f ON f.id = a.fazenda_id
LEFT JOIN pesagens p ON p.animal_id = a.id
WHERE a.status = 'ativo'
GROUP BY a.brinco, f.nome
HAVING MAX(p.data_pesagem) < CURRENT_DATE - INTERVAL '60 days' OR MAX(p.data_pesagem) IS NULL

UNION ALL

-- Vacinas vencidas
SELECT a.brinco, 'Vacina vencida: ' || es.descricao AS alerta, f.nome AS fazenda,
       'Sanitário' AS urgencia
FROM eventos_sanitarios es
JOIN animais a ON a.id = es.animal_id
JOIN fazendas f ON f.id = a.fazenda_id
WHERE es.tipo = 'vacinacao' AND a.status = 'ativo'
  AND es.proxima_dose < CURRENT_DATE;
