-- ------------------------------------------------
--  DADOS SINTÉTICOS (geredos pelo chatGPT)
-- ------------------------------------------------

-- 1) SALAS ─── 50 salas com capacidades de 10 a 500
INSERT INTO TB_SALA (NM_SALA, QTD_CAPACIDADE, DS_RECURSOS)
SELECT
  'Sala ' || gs,
  (gs * 10)::INT,
  'Recursos da sala ' || gs
FROM generate_series(1,50) AS gs;

-- 2) EVENTOS ─── 500 eventos: metade no passado, metade no futuro
INSERT INTO TB_EVENTO (NM_EVENTO, DT_INICIO, DT_FIM, DS_LOCAL_GERAL)
SELECT
  'Evento ' || gs.idx,
  current_date
    + (gs.offset_days * INTERVAL '1 day')            AS DT_INICIO,
  current_date
    + ((gs.offset_days + ((gs.idx % 5) + 1)) * INTERVAL '1 day')  AS DT_FIM,
  'Local ' || gs.idx
FROM (
  SELECT
    row_number() OVER () AS idx,
    CASE
      WHEN generate_series % 2 = 0 THEN  -- eventos passados
        -1 * floor(random()*365 + 1)::INT
      ELSE                               -- eventos futuros
        floor(random()*365 + 1)::INT
    END AS offset_days
  FROM generate_series(1,500)
) AS gs;

-- 3) INSTRUTORES ─── 200 instrutores
INSERT INTO TB_INSTRUTOR (NM_INSTRUTOR, DS_EMAIL, DS_TELEFONE)
SELECT
  'Instrutor ' || i,
  'instrutor' || i || '@exemplo.com',
  '+55 11 9' || lpad((100000 + i)::TEXT, 8, '0')
FROM generate_series(1,200) AS i;

-- 4) PARTICIPANTES ─── 1.000 participantes
INSERT INTO TB_PARTICIPANTE (NM_PARTICIPANTE, CD_MATRICULA, DS_EMAIL)
SELECT
  'Participante ' || p,
  'MAT' || lpad(p::TEXT, 5, '0'),
  'part' || p || '@exemplo.com'
FROM generate_series(1,1000) AS p;

-- 5) MATERIAIS ─── 300 materiais
INSERT INTO TB_MATERIAL (DS_DESCRICAO, TP_TIPO, QTD_TOTAL)
SELECT
  'Material ' || m,
  (ARRAY['IMPRESSO','ELETRONICO'])[1 + floor(random()*2)::INT],
  (10 + floor(random()*90))::INT
FROM generate_series(1,300) AS m;

-- 6) ATIVIDADES ─── 2.000 atividades vinculadas aleatoriamente
WITH nums AS (
  SELECT row_number() OVER () AS rn
  FROM generate_series(1,2000)
)
INSERT INTO TB_ATIVIDADE (DS_TITULO, DS_DESCRICAO, DT_INICIO, DT_FIM, ID_EVENTO, ID_SALA)
SELECT
  'Atividade ' || nums.rn,
  'Descrição para atividade ' || nums.rn,
  ev.DT_INICIO  + ((nums.rn % 7) * INTERVAL '1 day'),
  ev.DT_INICIO  + ((nums.rn % 7 + 1) * INTERVAL '1 day'),
  ev.ID_EVENTO,
  sl.ID_SALA
FROM nums
CROSS JOIN LATERAL (
  SELECT ID_EVENTO, DT_INICIO
  FROM TB_EVENTO
  ORDER BY md5(nums.rn::text || ID_EVENTO::text)
  LIMIT 1
) AS ev
CROSS JOIN LATERAL (
  SELECT ID_SALA
  FROM TB_SALA
  ORDER BY md5(nums.rn::text || ID_SALA::text)
  LIMIT 1
) AS sl;

-- 7) RL_ATIVIDADE_INSTRUTOR ─── cada atividade com 1–3 instrutores
INSERT INTO RL_ATIVIDADE_INSTRUTOR (ID_ATIVIDADE, ID_INSTRUTOR)
SELECT
  a.ID_ATIVIDADE,
  i.ID_INSTRUTOR
FROM TB_ATIVIDADE AS a
CROSS JOIN LATERAL (
  SELECT ID_INSTRUTOR
  FROM TB_INSTRUTOR
  ORDER BY random()
  LIMIT (1 + floor(random()*3))::INT
) AS i;

-- 8) INSCRIÇÕES ─── cada participante em 5–10 atividades
INSERT INTO TB_INSCRICAO (ID_PARTICIPANTE, ID_ATIVIDADE, DT_INSCRICAO)
SELECT
  p.ID_PARTICIPANTE,
  a.ID_ATIVIDADE,
  a.DT_INICIO - ((random()*7)::INT)
FROM TB_PARTICIPANTE AS p
CROSS JOIN LATERAL (
  SELECT ID_ATIVIDADE, DT_INICIO
  FROM TB_ATIVIDADE
  ORDER BY random()
  LIMIT (5 + floor(random()*6))::INT
) AS a;

-- 9) PRESENÇAS ─── toda sessão entre DT_INICIO e DT_FIM
INSERT INTO TB_PRESENCA (ID_INSCRICAO, DT_SESSAO, ST_PRESENCA)
SELECT
  insc.ID_INSCRICAO,
  sess.dt,
  (ARRAY['PRESENTE','AUSENTE'])[1 + floor(random()*2)::INT]
FROM TB_INSCRICAO AS insc
JOIN TB_ATIVIDADE  AS atv USING (ID_ATIVIDADE)
CROSS JOIN LATERAL (
  SELECT generate_series(atv.DT_INICIO, atv.DT_FIM, INTERVAL '1 day')::date AS dt
) AS sess;

-- 10) CERTIFICADOS ─── 100% de PRESENÇA
INSERT INTO TB_CERTIFICADO (ID_INSCRICAO, CD_CHAVE, DT_EMISSAO)
SELECT
  pr.ID_INSCRICAO,
  md5(pr.ID_INSCRICAO::text || clock_timestamp()::text),
  current_date
FROM (
  SELECT ID_INSCRICAO, bool_and(ST_PRESENCA = 'PRESENTE') AS todas
  FROM TB_PRESENCA
  GROUP BY ID_INSCRICAO
) AS pr
WHERE pr.todas;

-- 11) FEEDBACK ─── 25% das inscrições
INSERT INTO TB_FEEDBACK (ID_INSCRICAO, NR_NOTA, DS_COMENTARIO, DT_FEEDBACK)
SELECT
  insc.ID_INSCRICAO,
  (1 + floor(random()*5))::INT,
  'Comentário avaliativo para inscrição ' || insc.ID_INSCRICAO,
  current_date - ((random()*14)::INT)
FROM TB_INSCRICAO AS insc
WHERE random() < 0.25;

-- 12) PARCEIROS e PATROCÍNIOS
INSERT INTO TB_PARCEIRO (NM_PARCEIRO, TP_PARCEIRO, DS_CONTATO)
SELECT
  'Parceiro ' || p,
  (ARRAY['EMPRESA','ONG'])[1 + floor(random()*2)::INT],
  'contato' || p || '@parceiro.com'
FROM generate_series(1,200) AS p;

INSERT INTO TB_PATROCINIO (ID_PARCEIRO, ID_EVENTO, VL_CONTRIBUICAO)
SELECT
  pr.ID_PARCEIRO,
  ev.ID_EVENTO,
  (500 + random()*9500)::NUMERIC(12,2)
FROM TB_PARCEIRO AS pr
CROSS JOIN LATERAL (
  SELECT ID_EVENTO
  FROM TB_EVENTO
  ORDER BY random()
  LIMIT 1
) AS ev
LIMIT 500;

-- 13) HISTÓRICO DE PARTICIPAÇÃO ─── só atividades já concluídas
INSERT INTO TH_HISTORICO_PARTICIPACAO (ID_PARTICIPANTE, ID_ATIVIDADE, DT_CONCLUSAO)
SELECT
  insc.ID_PARTICIPANTE,
  insc.ID_ATIVIDADE,
  atv.DT_FIM
FROM TB_INSCRICAO AS insc
JOIN TB_ATIVIDADE AS atv USING (ID_ATIVIDADE)
WHERE atv.DT_FIM <= current_date;

-- 14) VOLUNTÁRIOS e TAREFAS
INSERT INTO TB_VOLUNTARIO (NM_VOLUNTARIO, TP_TIPO, DS_CONTATO)
SELECT
  'Voluntário ' || v,
  (ARRAY['ALUNO','EXTERNO'])[1 + floor(random()*2)::INT],
  'vol' || v || '@exemplo.com'
FROM generate_series(1,200) AS v;

INSERT INTO TB_TAREFA_VOLUNTARIO (ID_VOLUNTARIO, ID_ATIVIDADE, DS_DESCRICAO, ST_STATUS)
SELECT
  tv.ID_VOLUNTARIO,
  atv.ID_ATIVIDADE,
  'Tarefa para atividade ' || atv.ID_ATIVIDADE,
  (ARRAY['PENDENTE','CONCLUIDA'])[1 + floor(random()*2)::INT]
FROM TB_VOLUNTARIO AS tv
CROSS JOIN LATERAL (
  SELECT ID_ATIVIDADE
  FROM TB_ATIVIDADE
  ORDER BY random()
  LIMIT (SELECT ceil(count(*) * 0.2)::INT FROM TB_ATIVIDADE)
) AS atv;

-- 15) USO DE MATERIAIS ─── 1–5 materiais por atividade
INSERT INTO TB_USO_MATERIAL (ID_MATERIAL, ID_ATIVIDADE, QTD_UTILIZADA)
SELECT
  mat.ID_MATERIAL,
  atv.ID_ATIVIDADE,
  1 + floor(random()*5)::INT
FROM TB_MATERIAL AS mat
CROSS JOIN LATERAL (
  SELECT ID_ATIVIDADE
  FROM TB_ATIVIDADE
  ORDER BY random()
  LIMIT (1 + floor(random()*3))::INT
) AS atv;

-- 16) AVALIAÇÃO DE INSTRUTORES ─── 20% das duplas
INSERT INTO TB_AVALIACAO_INSTRUTOR (ID_INSTRUTOR, ID_ATIVIDADE, NR_NOTA, DS_COMENTARIO)
SELECT
  rai.ID_INSTRUTOR,
  rai.ID_ATIVIDADE,
  (1 + floor(random()*5))::INT,
  'Avaliação instrutor ' || rai.ID_INSTRUTOR
FROM RL_ATIVIDADE_INSTRUTOR AS rai
WHERE random() < 0.20;
