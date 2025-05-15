-- initdb/queries_intermediarias.sql

/*
  Queries intermediárias associadas a requisitos do minimundo estendido.
  Cada query envolve ao menos três tabelas e utiliza no mínimo duas das seguintes funções: JOIN, GROUP BY, WINDOW, COUNT.
*/

-- Query 1: Contagem de participantes por atividade e evento
-- Requisito: Verificar número de inscritos para comparação com capacidade da sala
SELECT
  e.id_evento,
  e.nm_evento,
  a.id_atividade,
  a.ds_titulo,
  COUNT(i.id_inscricao) AS qt_inscritos
FROM TB_EVENTO e
JOIN TB_ATIVIDADE a  ON a.id_evento = e.id_evento
JOIN TB_INSCRICAO i ON i.id_atividade = a.id_atividade
GROUP BY e.id_evento, e.nm_evento, a.id_atividade, a.ds_titulo;

-- Query 2: Atividades cuja capacidade da sala está excedida pelos inscritos
-- Requisito: Gestão de salas e verificação de conflitos de reserva
SELECT
  a.id_atividade,
  a.ds_titulo,
  s.id_sala,
  s.nm_sala,
  s.qtd_capacidade,
  COUNT(i.id_inscricao) AS inscritos,
  CASE WHEN COUNT(i.id_inscricao) > s.qtd_capacidade THEN 'EXCEDIDO' ELSE 'OK' END AS status_capacity
FROM TB_ATIVIDADE a
JOIN TB_SALA s           ON s.id_sala       = a.id_sala
JOIN TB_INSCRICAO i      ON i.id_atividade   = a.id_atividade
GROUP BY a.id_atividade, a.ds_titulo, s.id_sala, s.nm_sala, s.qtd_capacidade;

-- Query 3: Ranking dos melhores instrutores por média de feedback
-- Requisito: Avaliação de Instrutores
SELECT
  ins.id_instrutor,
  ins.nm_instrutor,
  AVG(fb.nr_nota) AS media_feedback,
  COUNT(fb.nr_nota) AS total_feedback
FROM TB_INSTRUTOR ins
JOIN RL_ATIVIDADE_INSTRUTOR rl ON rl.id_instrutor = ins.id_instrutor
JOIN TB_INSCRICAO i             ON i.id_atividade  = rl.id_atividade
JOIN TB_FEEDBACK fb             ON fb.id_inscricao = i.id_inscricao
GROUP BY ins.id_instrutor, ins.nm_instrutor
ORDER BY media_feedback DESC


-- Query 4: Contagem de parceiros patrocinadores por evento
-- Requisito: Parcerias e Patrocínios
SELECT
  e.id_evento,
  e.nm_evento,
  COUNT(pat.id_parceiro) AS qt_parceiros
FROM TB_EVENTO e
JOIN TB_PATROCINIO pat ON pat.id_evento = e.id_evento
JOIN TB_PARCEIRO par   ON par.id_parceiro = pat.id_parceiro
GROUP BY e.id_evento, e.nm_evento;

-- Query 5: Número de tarefas atribuídas a cada voluntário por atividade
-- Requisito: Gestão de Voluntários
SELECT
  v.id_voluntario,
  v.nm_voluntario,
  tv.id_atividade,
  COUNT(tv.id_tarefa_voluntario) AS qt_tarefas
FROM TB_VOLUNTARIO v
JOIN TB_TAREFA_VOLUNTARIO tv ON tv.id_voluntario = v.id_voluntario
JOIN TB_ATIVIDADE a          ON a.id_atividade   = tv.id_atividade
GROUP BY v.id_voluntario, v.nm_voluntario, tv.id_atividade;

-- Query 6: Monitoramento da carga horária proxy (tarefas) de voluntários com ranking
-- Requisito: Monitorar dedicação dos voluntários
SELECT
  v.id_voluntario,
  v.nm_voluntario,
  COUNT(tv.id_tarefa_voluntario) AS total_tarefas
FROM TB_VOLUNTARIO v
JOIN TB_TAREFA_VOLUNTARIO tv ON tv.id_voluntario = v.id_voluntario
JOIN TB_ATIVIDADE a          ON a.id_atividade   = tv.id_atividade
GROUP BY v.id_voluntario, v.nm_voluntario
ORDER BY total_tarefas DESC

-- Query 7: Total de material utilizado por atividade
-- Requisito: Controle de Material e Recursos
SELECT
  a.id_atividade,
  a.ds_titulo,
  m.id_material,
  m.ds_descricao,
  SUM(um.qtd_utilizada) AS total_utilizado
FROM TB_ATIVIDADE a
JOIN TB_USO_MATERIAL um ON um.id_atividade = a.id_atividade
JOIN TB_MATERIAL m      ON m.id_material   = um.id_material
GROUP BY a.id_atividade, a.ds_titulo, m.id_material, m.ds_descricao;

-- Query 8: Histórico de participação concluída por participante
-- Requisito: Histórico de Participação (atividades com conclusão <= hoje)
SELECT
  p.id_participante,
  p.nm_participante,
  COUNT(hp.id_historico_participacao) AS qt_concluidas
FROM TB_PARTICIPANTE p
JOIN TH_HISTORICO_PARTICIPACAO hp ON hp.id_participante = p.id_participante
JOIN TB_ATIVIDADE a               ON a.id_atividade     = hp.id_atividade
WHERE hp.dt_conclusao <= current_date
GROUP BY p.id_participante, p.nm_participante;

-- Query 9: Percentual médio de presença por atividade
-- Requisito: Inscrição e Presença
SELECT
  a.id_atividade,
  a.ds_titulo,
  ROUND(100.0 * SUM(CASE WHEN p.st_presenca = 'PRESENTE' THEN 1 ELSE 0 END) / COUNT(p.id_inscricao), 2) AS pct_presenca
FROM TB_ATIVIDADE a
JOIN TB_INSCRICAO i ON i.id_atividade   = a.id_atividade
JOIN TB_PRESENCA p   ON p.id_inscricao   = i.id_inscricao
GROUP BY a.id_atividade, a.ds_titulo;

-- Query 10: Média móvel de avaliação de instrutor ao longo do tempo
-- Requisito: Avaliação contínua de instrutores
SELECT
  ai.id_instrutor,
  instr.nm_instrutor,
  ai.id_atividade,
  a.dt_inicio,
  AVG(ai.nr_nota) OVER (PARTITION BY ai.id_instrutor ORDER BY a.dt_inicio ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS media_movel_3ultimas
FROM TB_AVALIACAO_INSTRUTOR ai
JOIN TB_INSTRUTOR instr ON instr.id_instrutor = ai.id_instrutor
JOIN TB_ATIVIDADE a     ON a.id_atividade     = ai.id_atividade;
