-- ======================================================
-- CRIAÇÃO DE ROLES E PERMISSÕES
-- ======================================================

-- 1) Cria os roles de acordo com os níveis de acesso
CREATE ROLE ROLE_DBA        NOLOGIN;
CREATE ROLE ROLE_SISTEMA    NOLOGIN;
CREATE ROLE ROLE_ANALISE    NOLOGIN;
CREATE ROLE ROLE_BACKUP     NOLOGIN;

-- 2) Concessão de privilégios
-- DBA (Admin): DDL, DML, DCL, roles, backups, logins
GRANT ALL PRIVILEGES
  ON ALL TABLES IN SCHEMA public
  TO ROLE_DBA;
GRANT ALL PRIVILEGES
  ON ALL SEQUENCES IN SCHEMA public
  TO ROLE_DBA;
GRANT ALL PRIVILEGES
  ON ALL FUNCTIONS IN SCHEMA public
  TO ROLE_DBA;

GRANT CREATE, CONNECT, TEMPORARY
  ON DATABASE eventdb
  TO ROLE_DBA;

-- Sistema (Aplicação/Serviço): DML + EXECUTE de procedures
GRANT INSERT, UPDATE, DELETE
  ON ALL TABLES IN SCHEMA public
  TO ROLE_SISTEMA;

GRANT EXECUTE
  ON ALL FUNCTIONS IN SCHEMA public
  TO ROLE_SISTEMA;

-- Análise (Analista de Dados): SELECT em tabelas e MVs
GRANT SELECT
  ON ALL TABLES IN SCHEMA public
  TO ROLE_ANALISE;

-- Backup (Operador de Backup): somente leitura para backup
GRANT SELECT
  ON ALL TABLES IN SCHEMA public
  TO ROLE_BACKUP;


-- ======================================================
-- DEFINIÇÃO DE ARTEFATOS
-- ======================================================

-- ======================================================
-- Artefato: Tela 1 – cadastro com validação
-- 1 comandos SELECT
-- 2 comando INSERT
-- 2 comandos UPDATE
-- ======================================================

CREATE OR REPLACE PROCEDURE SP_REALIZAR_INSCRICAO_E_AVALIACAO(
    p_id_participante INTEGER,
    p_id_atividade INTEGER,
    p_id_instrutor INTEGER,
    p_nota_feedback INTEGER,
    p_comentario_feedback TEXT,
    p_nota_avaliacao_instrutor INTEGER,
    p_comentario_avaliacao_instrutor TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_inscricao INTEGER;
    v_capacidade_sala INTEGER;
    v_total_inscritos INTEGER;
    v_email_participante VARCHAR(100);
BEGIN
    -- Comando SELECT 1: Validar capacidade da sala antes de inscrever
    SELECT s.QTD_CAPACIDADE INTO v_capacidade_sala
    FROM TB_SALA s
    JOIN TB_ATIVIDADE a ON s.ID_SALA = a.ID_SALA
    WHERE a.ID_ATIVIDADE = p_id_atividade;

    SELECT COUNT(*) INTO v_total_inscritos
    FROM TB_INSCRICAO
    WHERE ID_ATIVIDADE = p_id_atividade;

    IF v_total_inscritos >= v_capacidade_sala THEN
        RAISE EXCEPTION 'A capacidade da sala para a atividade % foi excedida.', p_id_atividade;
    END IF;

    START TRANSACTION;
        -- Comando INSERT 1: Realiza a inscrição do participante na atividade
        INSERT INTO TB_INSCRICAO (ID_PARTICIPANTE, ID_ATIVIDADE, DT_INSCRICAO)
        VALUES (p_id_participante, p_id_atividade, CURRENT_DATE)
        RETURNING ID_INSCRICAO INTO v_id_inscricao;
        -- Comando INSERT 2: Registra o feedback do participante para a atividade
        INSERT INTO TB_FEEDBACK (ID_INSCRICAO, NR_NOTA, DS_COMENTARIO, DT_FEEDBACK)
        VALUES (v_id_inscricao, p_nota_feedback, p_comentario_feedback, CURRENT_DATE);
    COMMIT;

    START TRANSACTION;
        -- Comando UPDATE 1: Atualiza o histórico de participação
        UPDATE TH_HISTORICO_PARTICIPACAO
        SET DT_CONCLUSAO = (SELECT DT_FIM FROM TB_ATIVIDADE WHERE ID_ATIVIDADE = p_id_atividade)
        WHERE ID_PARTICIPANTE = p_id_participante AND ID_ATIVIDADE = p_id_atividade;
        -- Comando UPDATE 2: Atualiza os dados de contato do participante
        SELECT DS_EMAIL INTO v_email_participante FROM TB_PARTICIPANTE WHERE ID_PARTICIPANTE = p_id_participante;
        UPDATE TB_PARTICIPANTE
        SET DS_EMAIL = v_email_participante
        WHERE ID_PARTICIPANTE = p_id_participante;
    COMMIT;
END;
$$;


-- ======================================================
-- Artefato: Tela 2 – cadastro ou validação

-- 2 comandos SELECT
-- 1 comando INSERT
-- 2 comandos UPDATE
-- 1 comandos DELETE
-- ======================================================

CREATE OR REPLACE PROCEDURE SP_CANCELAR_ATIVIDADE(
    p_id_atividade INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_inscricao_rec RECORD;
    v_titulo_atividade VARCHAR(100);
    v_id_evento INTEGER;
BEGIN
    -- Comando SELECT 1: Obter informações da atividade para log e validação
    SELECT DS_TITULO, ID_EVENTO INTO v_titulo_atividade, v_id_evento
    FROM TB_ATIVIDADE WHERE ID_ATIVIDADE = p_id_atividade;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Atividade com ID % não encontrada.', p_id_atividade;
    END IF;

    -- Comando SELECT 2: Validar se existem inscrições
    PERFORM ID_INSCRICAO FROM TB_INSCRICAO WHERE ID_ATIVIDADE = p_id_atividade LIMIT 1;

    -- Comando DELETE 1: Remove todos os registros de presença associados às inscrições da atividade
    DELETE FROM TB_PRESENCA WHERE ID_INSCRICAO IN (SELECT ID_INSCRICAO FROM TB_INSCRICAO WHERE ID_ATIVIDADE = p_id_atividade);
    
    -- Comando UPDATE 1: Atualiza o status das tarefas dos voluntários para 'PENDENTE'
    UPDATE TB_TAREFA_VOLUNTARIO SET ST_STATUS = 'PENDENTE' WHERE ID_ATIVIDADE = p_id_atividade;
    
    -- Comando UPDATE 2: Atualiza a descrição da atividade para indicar o cancelamento
    UPDATE TB_ATIVIDADE SET DS_DESCRICAO = 'CANCELADA - ' || DS_DESCRICAO WHERE ID_ATIVIDADE = p_id_atividade;
END;
$$;

-- ======================================================
-- Artefato: 4 gráficos analíticos estratégicos
-- Cada gráfico corresponde ao resultado de uma consulta avançada (diferentes da Entrega 1)
-- ======================================================

-- Gráfico 1: Impacto Financeiro e de Parcerias por Evento
CREATE MATERIALIZED VIEW VM_IMPACTO_FINANCEIRO_EVENTO AS
SELECT
    e.NM_EVENTO,
    COUNT(DISTINCT pat.ID_PARCEIRO) AS QTD_PARCEIROS,
    SUM(pat.VL_CONTRIBUICAO) AS TOTAL_PATROCINIO,
    (SELECT COUNT(*) FROM TB_INSCRICAO i JOIN TB_ATIVIDADE a ON i.ID_ATIVIDADE = a.ID_ATIVIDADE WHERE a.ID_EVENTO = e.ID_EVENTO) AS TOTAL_INSCRICOES,
    AVG(pat.VL_CONTRIBUICAO) AS MEDIA_CONTRIBUICAO_POR_PARCEIRO
FROM TB_EVENTO e
JOIN TB_PATROCINIO pat ON e.ID_EVENTO = pat.ID_EVENTO
GROUP BY e.ID_EVENTO, e.NM_EVENTO;

-- Gráfico 2: Histórico e Engajamento Consolidado por Participante
CREATE MATERIALIZED VIEW VM_HISTORICO_CONSOLIDADO_PARTICIPANTE AS
WITH AtividadesParticipante AS (
    SELECT
        p.ID_PARTICIPANTE,
        p.NM_PARTICIPANTE,
        a.DS_TITULO,
        e.NM_EVENTO,
        h.DT_CONCLUSAO
    FROM TB_PARTICIPANTE p
    JOIN TH_HISTORICO_PARTICIPACAO h ON p.ID_PARTICIPANTE = h.ID_PARTICIPANTE
    JOIN TB_ATIVIDADE a ON h.ID_ATIVIDADE = a.ID_ATIVIDADE
    JOIN TB_EVENTO e ON a.ID_EVENTO = e.ID_EVENTO
    WHERE h.DT_CONCLUSAO <= CURRENT_DATE
)
SELECT
    ID_PARTICIPANTE,
    NM_PARTICIPANTE,
    COUNT(*) AS QTD_ATIVIDADES_CONCLUIDAS,
    STRING_AGG(DS_TITULO, ', ') AS LISTA_ATIVIDADES
FROM AtividadesParticipante
GROUP BY ID_PARTICIPANTE, NM_PARTICIPANTE;

-- Gráfico 3: Desempenho e Avaliação Média dos Instrutores
CREATE MATERIALIZED VIEW VM_DESEMPENHO_GERAL_INSTRUTORES AS
SELECT
    i.NM_INSTRUTOR,
    i.DS_EMAIL,
    COUNT(DISTINCT a.ID_ATIVIDADE) AS QTD_ATIVIDADES_MINISTRADAS,
    AVG(av.NR_NOTA) AS NOTA_MEDIA_GERAL,
    COUNT(DISTINCT f.ID_FEEDBACK) AS FEEDBACKS_TOTAIS
FROM TB_INSTRUTOR i
JOIN TB_AVALIACAO_INSTRUTOR av ON i.ID_INSTRUTOR = av.ID_INSTRUTOR
JOIN TB_ATIVIDADE a ON av.ID_ATIVIDADE = a.ID_ATIVIDADE
LEFT JOIN TB_INSCRICAO ins ON ins.ID_ATIVIDADE = a.ID_ATIVIDADE
LEFT JOIN TB_FEEDBACK f ON f.ID_INSCRICAO = ins.ID_INSCRICAO
GROUP BY i.ID_INSTRUTOR, i.NM_INSTRUTOR, i.DS_EMAIL;

-- Gráfico 4: Popularidade e Engajamento nas Atividades
CREATE MATERIALIZED VIEW VM_ENGAJAMENTO_POR_ATIVIDADE AS
SELECT
    a.DS_TITULO,
    e.NM_EVENTO,
    COUNT(DISTINCT i.ID_INSCRICAO) AS NUM_INSCRITOS,
    COUNT(DISTINCT CASE WHEN pr.ST_PRESENCA = 'PRESENTE' THEN pr.ST_PRESENCA END) AS NUM_PRESENTES,
    AVG(f.NR_NOTA) AS MEDIA_FEEDBACK
FROM TB_ATIVIDADE a
JOIN TB_EVENTO e ON a.ID_EVENTO = e.ID_EVENTO
LEFT JOIN TB_INSCRICAO i ON a.ID_ATIVIDADE = i.ID_ATIVIDADE
LEFT JOIN TB_PRESENCA pr ON i.ID_INSCRICAO = pr.ID_INSCRICAO
LEFT JOIN TB_FEEDBACK f ON i.ID_INSCRICAO = f.ID_INSCRICAO
GROUP BY a.ID_ATIVIDADE, a.DS_TITULO, e.NM_EVENTO
ORDER BY NUM_INSCRITOS DESC;

-- ======================================================
-- Artefato: 6 gráficos analíticos operacionais
-- 2 gráficos devem ser geradas por uma consulta avançada e 4 por consultas intermediárias (diferentes da Entrega 1)
-- ======================================================

-- Gráfico Operacional 1 (Avançada): Taxa de Ocupação das Salas
CREATE MATERIALIZED VIEW VM_OCUPACAO_SALA_ATIVIDADE AS
SELECT
    s.NM_SALA,
    a.DS_TITULO,
    s.QTD_CAPACIDADE,
    COUNT(i.ID_INSCRICAO) AS QTD_INSCRITOS,
    (CAST(COUNT(i.ID_INSCRICAO) AS NUMERIC) / NULLIF(s.QTD_CAPACIDADE, 0)) * 100 AS PERCENTUAL_OCUPACAO,
    ROW_NUMBER() OVER(PARTITION BY s.NM_SALA ORDER BY a.DT_INICIO) AS ORDEM_ATIVIDADE_NA_SALA
FROM TB_SALA s
JOIN TB_ATIVIDADE a ON s.ID_SALA = a.ID_SALA
LEFT JOIN TB_INSCRICAO i ON a.ID_ATIVIDADE = i.ID_ATIVIDADE
WHERE a.DT_INICIO > CURRENT_DATE
GROUP BY s.ID_SALA, s.NM_SALA, a.ID_ATIVIDADE, a.DS_TITULO, s.QTD_CAPACIDADE, a.DT_INICIO;

-- Gráfico Operacional 2 (Avançada): Acompanhamento de Presença e Emissão de Certificados
CREATE MATERIALIZED VIEW VM_STATUS_CERTIFICACAO_PARTICIPANTE AS
WITH PRESENCA_CONTAGEM AS (
    SELECT
        i.ID_INSCRICAO,
        COUNT(p.DT_SESSAO) AS DIAS_PRESENTE
    FROM TB_INSCRICAO i
    JOIN TB_PRESENCA p ON i.ID_INSCRICAO = p.ID_INSCRICAO
    WHERE p.ST_PRESENCA = 'PRESENTE'
    GROUP BY i.ID_INSCRICAO
)
SELECT
    part.NM_PARTICIPANTE,
    a.DS_TITULO,
    (a.DT_FIM - a.DT_INICIO + 1) AS DIAS_TOTAIS_ATIVIDADE,
    COALESCE(pc.DIAS_PRESENTE, 0) AS DIAS_PRESENTE,
    CASE
        WHEN cert.ID_CERTIFICADO IS NOT NULL THEN 'EMITIDO'
        ELSE 'PENDENTE'
    END AS STATUS_CERTIFICADO
FROM TB_ATIVIDADE a
JOIN TB_INSCRICAO i ON a.ID_ATIVIDADE = i.ID_ATIVIDADE
JOIN TB_PARTICIPANTE part ON i.ID_PARTICIPANTE = part.ID_PARTICIPANTE
LEFT JOIN PRESENCA_CONTAGEM pc ON i.ID_INSCRICAO = pc.ID_INSCRICAO
LEFT JOIN TB_CERTIFICADO cert ON i.ID_INSCRICAO = cert.ID_INSCRICAO
GROUP BY part.ID_PARTICIPANTE, part.NM_PARTICIPANTE, a.ID_ATIVIDADE, a.DS_TITULO, 
         a.DT_INICIO, a.DT_FIM, pc.DIAS_PRESENTE, cert.ID_CERTIFICADO;

-- Gráfico Operacional 3 (Intermediária): Lista de Inscritos por Atividade Futura
CREATE MATERIALIZED VIEW VM_INSCRITOS_ATIVIDADES_FUTURAS AS
SELECT
    e.NM_EVENTO,
    a.DS_TITULO,
    COUNT(p.ID_PARTICIPANTE) AS QTD_INSCRITOS
FROM TB_ATIVIDADE a
JOIN TB_EVENTO e ON a.ID_EVENTO = e.ID_EVENTO
JOIN TB_INSCRICAO i ON a.ID_ATIVIDADE = i.ID_ATIVIDADE
JOIN TB_PARTICIPANTE p ON i.ID_PARTICIPANTE = p.ID_PARTICIPANTE
WHERE a.DT_INICIO > CURRENT_DATE
GROUP BY e.ID_EVENTO, e.NM_EVENTO, a.ID_ATIVIDADE, a.DS_TITULO;

-- Gráfico Operacional 4 (Intermediária): Uso de Materiais por Tipo
CREATE MATERIALIZED VIEW VM_USO_MATERIAIS_POR_TIPO AS
SELECT
    m.TP_TIPO,
    a.DS_TITULO,
    SUM(um.QTD_UTILIZADA) AS QTD_TOTAL_UTILIZADA
FROM TB_MATERIAL m
JOIN TB_USO_MATERIAL um ON m.ID_MATERIAL = um.ID_MATERIAL
JOIN TB_ATIVIDADE a ON um.ID_ATIVIDADE = a.ID_ATIVIDADE
GROUP BY m.TP_TIPO, a.ID_ATIVIDADE, a.DS_TITULO;

-- Gráfico Operacional 5 (Intermediária): Status das Tarefas de Voluntários
CREATE MATERIALIZED VIEW VM_ACOMPANHAMENTO_TAREFAS_VOLUNTARIOS AS
SELECT
    v.NM_VOLUNTARIO,
    a.DS_TITULO,
    t.ST_STATUS,
    COUNT(t.ID_TAREFA_VOLUNTARIO) AS NUM_TAREFAS_ATRIBUIDAS
FROM TB_VOLUNTARIO v
JOIN TB_TAREFA_VOLUNTARIO t ON v.ID_VOLUNTARIO = t.ID_VOLUNTARIO
JOIN TB_ATIVIDADE a ON t.ID_ATIVIDADE = a.ID_ATIVIDADE
GROUP BY v.ID_VOLUNTARIO, v.NM_VOLUNTARIO, a.ID_ATIVIDADE, a.DS_TITULO, t.ST_STATUS;

-- Gráfico Operacional 6 (Intermediária): Certificados Emitidos por Evento
CREATE MATERIALIZED VIEW VM_CERTIFICADOS_POR_EVENTO AS
SELECT
    e.NM_EVENTO,
    COALESCE(p.NM_PARCEIRO, 'SEM PARCEIRO') AS NM_PARCEIRO,
    COUNT(c.ID_CERTIFICADO) AS QTD_CERTIFICADOS_EMITIDOS
FROM TB_CERTIFICADO c
JOIN TB_INSCRICAO i ON c.ID_INSCRICAO = i.ID_INSCRICAO
JOIN TB_ATIVIDADE a ON i.ID_ATIVIDADE = a.ID_ATIVIDADE
JOIN TB_EVENTO e ON a.ID_EVENTO = e.ID_EVENTO
LEFT JOIN TB_PATROCINIO pat ON e.ID_EVENTO = pat.ID_EVENTO
LEFT JOIN TB_PARCEIRO p ON pat.ID_PARCEIRO = p.ID_PARCEIRO
GROUP BY e.ID_EVENTO, e.NM_EVENTO, p.ID_PARCEIRO, p.NM_PARCEIRO;
