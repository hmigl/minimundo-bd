-- ------------------------------------------------
--  DADOS SINTÉTICOS (geredos pelo chatGPT)
-- ------------------------------------------------

BEGIN;

-- 1) Preencher tabelas principais sem dependências

-- TB_SALA: 1000 salas
INSERT INTO TB_SALA (NM_SALA, QTD_CAPACIDADE, DS_RECURSOS)
SELECT
  'Sala ' || lpad(g::text,4,'0'),
  (floor(random()*100) + 1)::integer,
  CASE floor(random()*3)
    WHEN 0 THEN 'Projetor'
    WHEN 1 THEN 'Ar condicionado'
    ELSE 'Wi-Fi'
  END
FROM generate_series(1,1000) AS g;

-- TB_EVENTO: 1000 eventos
INSERT INTO TB_EVENTO (NM_EVENTO, DT_INICIO, DT_FIM, DS_LOCAL_GERAL)
SELECT
  'Evento ' || lpad(g::text,4,'0'),
  (date '2024-01-01' + (g % 365) * interval '1 day')::date,
  ((date '2024-01-01' + (g % 365) * interval '1 day') + ((floor(random()*10)+1) * interval '1 day'))::date,
  'Local ' || (floor(random()*100)+1)
FROM generate_series(1,1000) AS g;

-- TB_INSTRUTOR: 1000 instrutores
INSERT INTO TB_INSTRUTOR (NM_INSTRUTOR, DS_EMAIL, DS_TELEFONE)
SELECT
  'Instrutor ' || lpad(g::text,4,'0'),
  'instrutor' || g || '@exemplo.com',
  '+55 71 ' || lpad((100000000 + floor(random()*900000000))::text,9,'0')
FROM generate_series(1,1000) AS g;

-- TB_PARTICIPANTE: 1000 participantes
INSERT INTO TB_PARTICIPANTE (NM_PARTICIPANTE, CD_MATRICULA, DS_EMAIL)
SELECT
  'Participante ' || lpad(g::text,4,'0'),
  'MAT' || lpad(g::text,4,'0'),
  'participante' || g || '@mail.com'
FROM generate_series(1,1000) AS g;

-- TB_MATERIAL: 1000 materiais
INSERT INTO TB_MATERIAL (DS_DESCRICAO, TP_TIPO, QTD_TOTAL)
SELECT
  'Material descricao ' || g,
  CASE WHEN random() < 0.5 THEN 'IMPRESSO' ELSE 'ELETRONICO' END,
  (floor(random()*50))::integer
FROM generate_series(1,1000) AS g;

-- TB_PARCEIRO: 1000 parceiros
INSERT INTO TB_PARCEIRO (NM_PARCEIRO, TP_PARCEIRO, DS_CONTATO)
SELECT
  'Parceiro ' || lpad(g::text,4,'0'),
  CASE WHEN random() < 0.5 THEN 'EMPRESA' ELSE 'ONG' END,
  'contato' || g || '@parceiro.com'
FROM generate_series(1,1000) AS g;

-- TB_VOLUNTARIO: 1000 voluntarios
INSERT INTO TB_VOLUNTARIO (NM_VOLUNTARIO, TP_TIPO, DS_CONTATO)
SELECT
  'Voluntario ' || lpad(g::text,4,'0'),
  CASE WHEN random() < 0.5 THEN 'ALUNO' ELSE 'EXTERNO' END,
  'vol' || g || '@voluntario.com'
FROM generate_series(1,1000) AS g;

-- 2) Tabelas com FKs simples

-- TB_ATIVIDADE: 1000 atividades
INSERT INTO TB_ATIVIDADE (DS_TITULO, DS_DESCRICAO, DT_INICIO, DT_FIM, ID_EVENTO, ID_SALA)
SELECT
  'Atividade ' || lpad(g::text,4,'0'),
  'Descricao da atividade ' || g,
  e.dt_inicio,
  e.dt_inicio + ((floor(random()*5)+1) * interval '1 day'),
  e.id_evento,
  s.id_sala
FROM generate_series(1,1000) AS g
JOIN TB_EVENTO e ON e.id_evento = ((g % 1000) + 1)
JOIN TB_SALA    s ON s.id_sala    = (((g * 7) % 1000) + 1);

-- TB_PATROCINIO: 1000 patrocinios
INSERT INTO TB_PATROCINIO (ID_PARCEIRO, ID_EVENTO, VL_CONTRIBUICAO)
SELECT
  ((g % 1000) + 1),
  ((g * 3 % 1000) + 1),
  round((random()*10000)::numeric,2)
FROM generate_series(1,1000) AS g;

-- 3) Tabelas relacionais e dependentes

-- RL_ATIVIDADE_INSTRUTOR: associar 1500 instrutores a atividades (alguns repetidos)
INSERT INTO RL_ATIVIDADE_INSTRUTOR (ID_ATIVIDADE, ID_INSTRUTOR)
SELECT DISTINCT
  ((floor(random()*1000)+1)::integer),
  ((floor(random()*1000)+1)::integer)
FROM generate_series(1,1500) AS g
LIMIT 1500;

-- TB_INSCRICAO: 1000 inscricoes únicas
INSERT INTO TB_INSCRICAO (ID_PARTICIPANTE, ID_ATIVIDADE, DT_INSCRICAO)
SELECT
  p.participant_id,
  p.activity_id,
  (date '2024-06-01' + (floor(random()*90) * interval '1 day'))::date
FROM (
  SELECT DISTINCT
    ((floor(random()*1000)+1)::integer) AS participant_id,
    ((floor(random()*1000)+1)::integer) AS activity_id
  FROM generate_series(1,3000)
) p
LIMIT 1000;

-- TB_TAREFA_VOLUNTARIO: 1000 tarefas
INSERT INTO TB_TAREFA_VOLUNTARIO (ID_VOLUNTARIO, ID_ATIVIDADE, DS_DESCRICAO, ST_STATUS)
SELECT
  ((floor(random()*1000)+1)),
  ((floor(random()*1000)+1)),
  'Tarefa para voluntario ' || g,
  CASE WHEN random()<0.7 THEN 'PENDENTE' ELSE 'CONCLUIDA' END
FROM generate_series(1,1000) AS g;

-- TB_USO_MATERIAL: 1000 usos
INSERT INTO TB_USO_MATERIAL (ID_MATERIAL, ID_ATIVIDADE, QTD_UTILIZADA)
SELECT
  ((floor(random()*1000)+1)),
  ((floor(random()*1000)+1)),
  (floor(random()*5))::integer
FROM generate_series(1,1000) AS g;

-- TB_FEEDBACK: 1000 feedbacks
INSERT INTO TB_FEEDBACK (ID_INSCRICAO, NR_NOTA, DS_COMENTARIO, DT_FEEDBACK)
SELECT
  ((floor(random()*1000)+1)),
  (floor(random()*5)+1)::integer,
  'Comentario de feedback ' || g || ' - excelente!',
  (date '2024-06-01' + (floor(random()*90) * interval '1 day'))::date
FROM generate_series(1,1000) AS g;

-- TH_HISTORICO_PARTICIPACAO: 1000 historicos
INSERT INTO TH_HISTORICO_PARTICIPACAO (ID_PARTICIPANTE, ID_ATIVIDADE, DT_CONCLUSAO)
SELECT
  ((floor(random()*1000)+1)),
  ((floor(random()*1000)+1)),
  (date '2024-06-01' + (floor(random()*180) * interval '1 day'))::date
FROM generate_series(1,1000) AS g;

-- TB_PRESENCA: 1000 presencas dentro do periodo da atividade
INSERT INTO TB_PRESENCA (ID_INSCRICAO, DT_SESSAO, ST_PRESENCA)
SELECT
  insc.id_inscricao,
  (insc.period_start + (floor(random() * (insc.period_end - insc.period_start + 1)) * interval '1 day'))::date,
  CASE WHEN random()<0.8 THEN 'PRESENTE' ELSE 'AUSENTE' END
FROM (
  SELECT i.id_inscricao,
         a.dt_inicio AS period_start,
         a.dt_fim    AS period_end
  FROM TB_INSCRICAO i
  JOIN TB_ATIVIDADE a ON i.id_atividade = a.id_atividade
  LIMIT 1000
) insc;

-- TB_CERTIFICADO: 1000 certificados únicos
INSERT INTO TB_CERTIFICADO (ID_INSCRICAO, CD_CHAVE, DT_EMISSAO)
SELECT
  i.id_inscricao,
  md5(random()::text),
  (date '2024-06-01' + (floor(random()*90) * interval '1 day'))::date
FROM TB_INSCRICAO i
LIMIT 1000;

-- TB_AVALIACAO_INSTRUTOR: 1000 avaliacoes
INSERT INTO TB_AVALIACAO_INSTRUTOR (ID_INSTRUTOR, ID_ATIVIDADE, NR_NOTA, DS_COMENTARIO)
SELECT
  ((floor(random()*1000)+1)),
  ((floor(random()*1000)+1)),
  (floor(random()*5)+1)::integer,
  'Comentário instrutor ' || g
FROM generate_series(1,1000) AS g;

COMMIT;
