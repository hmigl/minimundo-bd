-- avancadas.sql
/*
  Queries avançadas (cada uma envolve ao menos três tabelas e utiliza
  pelo menos três das seguintes funções: SUB-CONSULTAS, JOIN, GROUP BY, WINDOW e COUNT).
  Cada query está associada explicitamente a um requisito do minimundo estendido.
*/

-- Query: Utilização de material por evento e índice de reabastecimento
-- Requisito: Controle de Material e Recursos
SELECT
  ev.id_evento,
  ev.nm_evento,
  m.id_material,
  m.ds_descricao,
  SUM(um.qtd_utilizada) AS total_utilizado,
  m.qtd_total,
  ROUND(100.0 * SUM(um.qtd_utilizada) / m.qtd_total, 2) AS pct_consumido
FROM TB_EVENTO ev
JOIN TB_ATIVIDADE a ON a.id_evento = ev.id_evento
JOIN TB_USO_MATERIAL um ON um.id_atividade = a.id_atividade
JOIN TB_MATERIAL m ON m.id_material = um.id_material
WHERE m.qtd_total != 0
GROUP BY ev.id_evento, ev.nm_evento, m.id_material, m.ds_descricao, m.qtd_total
HAVING SUM(um.qtd_utilizada) > 0.8 * m.qtd_total;

-- Query: Média móvel de inscritos por atividade por evento (últimas 3 atividades)
-- Requisito: Vinculação de Atividades e comparação com capacidade
SELECT
  ev.id_evento,
  ev.nm_evento,
  a.id_atividade,
  COUNT(ins.id_inscricao) OVER (PARTITION BY ev.id_evento ORDER BY a.dt_inicio ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS inscritos_3ultimas
FROM TB_EVENTO ev
JOIN TB_ATIVIDADE a ON a.id_evento = ev.id_evento
LEFT JOIN TB_INSCRICAO ins ON ins.id_atividade = a.id_atividade;

-- Query: Instrutores sem avaliação mínima média de 3.5
-- Requisito: Avaliação de Instrutores
SELECT
  instr.id_instrutor,
  instr.nm_instrutor,
  AVG(ai.nr_nota) AS media_nota,
  COUNT(ai.id_avaliacao_instrutor) AS total_avaliacoes
FROM TB_INSTRUTOR instr
JOIN TB_AVALIACAO_INSTRUTOR ai ON ai.id_instrutor = instr.id_instrutor
JOIN TB_ATIVIDADE a ON a.id_atividade = ai.id_atividade
GROUP BY instr.id_instrutor, instr.nm_instrutor
HAVING AVG(ai.nr_nota) < 3.5;

-- Query: Participantes que concluíram atividades mas não receberam certificado
-- Requisito: Emissão de Certificados
SELECT
  p.id_participante,
  p.nm_participante,
  a.id_atividade,
  a.ds_titulo,
  hp.dt_conclusao
FROM TH_HISTORICO_PARTICIPACAO hp
JOIN TB_PARTICIPANTE p ON p.id_participante = hp.id_participante
JOIN TB_ATIVIDADE a ON a.id_atividade = hp.id_atividade
LEFT JOIN TB_CERTIFICADO c ON c.id_inscricao = (
    SELECT i.id_inscricao
    FROM TB_INSCRICAO i
    WHERE i.id_participante = hp.id_participante
      AND i.id_atividade = hp.id_atividade
)
WHERE hp.dt_conclusao <= current_date
  AND c.id_certificado IS NULL;

-- Query: Top voluntários por carga de tarefas móvel (year)
-- Requisito: Monitoramento da carga horária dedicada pelos voluntários
SELECT DISTINCT
  v.id_voluntario,
  v.nm_voluntario,
  COUNT(tv.id_tarefa_voluntario) OVER (PARTITION BY v.id_voluntario ORDER BY tv.id_tarefa_voluntario ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS tarefas_acumuladas,
  ROW_NUMBER() OVER (ORDER BY COUNT(tv.id_tarefa_voluntario) DESC) AS ranking_global
FROM TB_VOLUNTARIO v
JOIN TB_TAREFA_VOLUNTARIO tv ON tv.id_voluntario = v.id_voluntario
JOIN TB_ATIVIDADE a ON a.id_atividade = tv.id_atividade
WHERE a.dt_inicio BETWEEN '2024-01-01' AND '2024-06-30'
GROUP BY v.id_voluntario, v.nm_voluntario, tv.id_tarefa_voluntario;

-- Query: Eventos com taxa de presença média acima de 90%
-- Requisito: Inscrição, Presença e capacidade de sala
SELECT
  ev.id_evento,
  ev.nm_evento,
  ROUND(100.0 * SUM(CASE WHEN p.st_presenca = 'PRESENTE' THEN 1 ELSE 0 END) / COUNT(p.id_inscricao), 2) AS pct_presenca
FROM TB_EVENTO ev
JOIN TB_INSCRICAO ins ON ins.id_atividade IN (
  SELECT id_atividade FROM TB_ATIVIDADE WHERE id_evento = ev.id_evento
)
JOIN TB_PRESENCA p ON p.id_inscricao = ins.id_inscricao
GROUP BY ev.id_evento, ev.nm_evento
HAVING ROUND(100.0 * SUM(CASE WHEN p.st_presenca = 'PRESENTE' THEN 1 ELSE 0 END) / COUNT(p.id_inscricao), 2) > 90
limit 50

-- Query: Participantes sem feedback nas atividades concluídas
-- Requisito: Feedback obrigatório por inscrição
SELECT
  p.id_participante,
  p.nm_participante,
  a.id_atividade,
  a.ds_titulo
FROM TB_PARTICIPANTE p
JOIN TH_HISTORICO_PARTICIPACAO hp ON hp.id_participante = p.id_participante
JOIN TB_ATIVIDADE a ON a.id_atividade = hp.id_atividade
LEFT JOIN TB_FEEDBACK fb ON fb.id_inscricao = (
  SELECT i.id_inscricao
  FROM TB_INSCRICAO i
  WHERE i.id_participante = p.id_participante AND i.id_atividade = a.id_atividade
)
WHERE hp.dt_conclusao <= current_date
  AND fb.id_feedback IS NULL;

-- Query: Ranking de parceiros por contribuição acumulada no ano
-- Requisito: Consolidar valores de patrocínio por parceiro
SELECT
  par.id_parceiro,
  par.nm_parceiro,
  SUM(pat.vl_contribuicao) AS total_contribuicoes,
  RANK() OVER (ORDER BY SUM(pat.vl_contribuicao) DESC) AS posicao
FROM TB_PARCEIRO par
JOIN TB_PATROCINIO pat ON pat.id_parceiro = par.id_parceiro
JOIN TB_EVENTO e ON e.id_evento = pat.id_evento
WHERE DATE_PART('year', e.dt_inicio) = 2024
GROUP BY par.id_parceiro, par.nm_parceiro;

-- Query: Identificar materiais com estoque crítico (uso > 75%) e previsão de falta
-- Requisito: Planejamento de reabastecimento
SELECT
  m.id_material,
  m.ds_descricao,
  m.qtd_total,
  uso.total_utilizado,
  ROUND(100.0 * uso.total_utilizado / m.qtd_total, 2) AS pct_consumido
FROM TB_MATERIAL m
JOIN (
  SELECT id_material, SUM(qtd_utilizada) AS total_utilizado
  FROM TB_USO_MATERIAL
  GROUP BY id_material
  HAVING SUM(qtd_utilizada) > 0
) uso ON uso.id_material = m.id_material
WHERE m.qtd_total > 0
  AND uso.total_utilizado > 0.75 * m.qtd_total;

-- Query: Média de avaliações de instrutores por período trimestral
-- Requisito: Cálculo da média de avaliação ao longo do tempo
SELECT
  instr.id_instrutor,
  instr.nm_instrutor,
  DATE_TRUNC('quarter', a.dt_inicio) AS trimestre,
  AVG(ai.nr_nota) AS media_trimestral,
  COUNT(ai.id_avaliacao_instrutor) AS total_avaliacoes
FROM TB_AVALIACAO_INSTRUTOR ai
JOIN TB_INSTRUTOR instr ON instr.id_instrutor = ai.id_instrutor
JOIN TB_ATIVIDADE a ON a.id_atividade = ai.id_atividade
GROUP BY instr.id_instrutor, instr.nm_instrutor, DATE_TRUNC('quarter', a.dt_inicio)
ORDER BY instr.id_instrutor, trimestre;
