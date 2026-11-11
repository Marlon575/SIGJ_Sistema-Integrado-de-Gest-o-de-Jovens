/*
 SIGJ — modelo PostgreSQL para revisão
 Base: gestao_juridica_integrada (criada pelo serviço PostgreSQL no Docker)
 Compatível com PostgreSQL 16. Este ficheiro é uma proposta: não foi aplicado.

 Entidades alinhadas com config/entities.php e os ecrãs atuais:
 clientes, processos, supervisores, estagiarios, candidatos, vagas, prazos,
 utilizadores. Não inclui advogados, competências, documentos ou candidaturas.

 Escopo/segurança: criado_por regista autoria. A aplicação deve aplicar autorização
 e filtros de propriedade em todas as consultas; não basta esconder opções na interface.
 Use PDO e prepared statements. Limites de campos e CHECK não substituem isso.
 Telefones guardam exatamente 9 dígitos locais (sem indicativo internacional).

 Auditoria: antes de operações, a aplicação deve definir por transação:
 SET LOCAL app.user_id = 'id'; SET LOCAL app.perfil = 'perfil';
 */

BEGIN;
CREATE SCHEMA IF NOT EXISTS seguranca;
CREATE SCHEMA IF NOT EXISTS juridico;
CREATE SCHEMA IF NOT EXISTS estagios;
CREATE SCHEMA IF NOT EXISTS recrutamento;
CREATE SCHEMA IF NOT EXISTS relatorios;

-- Perfis de acesso e contas. Permissões pessoais podem ser configuradas pelo Administrador.
CREATE TABLE seguranca.perfis (
  perfil_id SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo VARCHAR(40) NOT NULL UNIQUE CHECK (length(trim(codigo)) BETWEEN 2 AND 40),
  descricao VARCHAR(300) NOT NULL, ativo BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE seguranca.utilizadores (
  utilizador_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome VARCHAR(120) NOT NULL CHECK (length(trim(nome)) BETWEEN 2 AND 120),
  email VARCHAR(254) NOT NULL UNIQUE,
  senha_hash VARCHAR(255) NOT NULL,
  perfil_id SMALLINT NOT NULL REFERENCES seguranca.perfis(perfil_id) ON DELETE RESTRICT,
  supervisor_id BIGINT,
  ativo BOOLEAN NOT NULL DEFAULT TRUE,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (email=lower(trim(email)) AND email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
);
CREATE TABLE seguranca.permissoes_perfil (
  perfil_id SMALLINT NOT NULL REFERENCES seguranca.perfis(perfil_id) ON DELETE RESTRICT,
  modulo VARCHAR(30) NOT NULL CHECK (modulo IN ('dashboard','clientes','processos','supervisores','estagiarios','candidatos','vagas','prazos','utilizadores','relatorios','configuracoes')),
  accao VARCHAR(10) NOT NULL CHECK (accao IN ('ver','criar','editar')),
  ativo BOOLEAN NOT NULL DEFAULT TRUE, PRIMARY KEY(perfil_id,modulo,accao)
);
CREATE TABLE seguranca.permissoes_utilizador (
  utilizador_id BIGINT NOT NULL REFERENCES seguranca.utilizadores(utilizador_id) ON DELETE RESTRICT,
  modulo VARCHAR(30) NOT NULL,
  accao VARCHAR(10) NOT NULL CHECK (accao IN ('ver','criar','editar')),
  permitido BOOLEAN NOT NULL, ativo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY(utilizador_id,modulo,accao)
);
CREATE TABLE seguranca.auditoria (
  auditoria_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  utilizador_id BIGINT REFERENCES seguranca.utilizadores(utilizador_id) ON DELETE RESTRICT,
  perfil_no_momento VARCHAR(20), tabela VARCHAR(60) NOT NULL,
  registo_id BIGINT, operacao VARCHAR(10) NOT NULL CHECK (operacao IN ('INSERT','UPDATE')),
  antes JSONB, depois JSONB, ocorrido_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Pessoas e processos jurídicos. criado_por implementa o vínculo ao utilizador responsável.
CREATE TABLE juridico.clientes (
  cliente_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome VARCHAR(120) NOT NULL CHECK (length(trim(nome)) BETWEEN 2 AND 120),
  email VARCHAR(254), telefone VARCHAR(9) NOT NULL CHECK (telefone ~ '^[0-9]{9}$'),
  endereco VARCHAR(250), ativo BOOLEAN NOT NULL DEFAULT TRUE, criado_por BIGINT NOT NULL REFERENCES seguranca.utilizadores(utilizador_id) ON DELETE RESTRICT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now(), actualizado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (email IS NULL OR (email=lower(trim(email)) AND email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'))
);
CREATE TABLE juridico.processos (
  processo_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cliente_id BIGINT NOT NULL REFERENCES juridico.clientes(cliente_id) ON DELETE RESTRICT,
  numero VARCHAR(30) NOT NULL UNIQUE CHECK (length(trim(numero)) BETWEEN 1 AND 30),
  tipo VARCHAR(80) NOT NULL, descricao VARCHAR(2000),
  estado VARCHAR(20) NOT NULL DEFAULT 'Pendente' CHECK (estado IN ('Pendente','Em andamento','Concluído','Cancelado')),
  data_abertura DATE NOT NULL DEFAULT CURRENT_DATE, ativo BOOLEAN NOT NULL DEFAULT TRUE,
  criado_por BIGINT NOT NULL REFERENCES seguranca.utilizadores(utilizador_id) ON DELETE RESTRICT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now(), actualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE juridico.prazos (
  prazo_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  processo_id BIGINT NOT NULL REFERENCES juridico.processos(processo_id) ON DELETE RESTRICT,
  descricao VARCHAR(180) NOT NULL, data_limite DATE NOT NULL, data_entrega DATE,
  nota_atraso VARCHAR(1500), ativo BOOLEAN NOT NULL DEFAULT TRUE,
  criado_por BIGINT NOT NULL REFERENCES seguranca.utilizadores(utilizador_id) ON DELETE RESTRICT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now(), actualizado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (data_entrega IS NULL OR data_entrega <= CURRENT_DATE),
  CHECK (data_entrega IS NULL OR data_entrega <= data_limite OR length(trim(coalesce(nota_atraso,''))) > 0)
);

-- Supervisores são criados pelo Administrador. Estagiários ficam associados ao supervisor.
CREATE TABLE estagios.supervisores (
  supervisor_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  utilizador_id BIGINT UNIQUE REFERENCES seguranca.utilizadores(utilizador_id) ON DELETE RESTRICT,
  nome VARCHAR(120) NOT NULL CHECK (length(trim(nome)) BETWEEN 2 AND 120),
  email VARCHAR(254) NOT NULL UNIQUE,
  telefone VARCHAR(9) NOT NULL CHECK (telefone ~ '^[0-9]{9}$'),
  especialidade VARCHAR(100) NOT NULL,
  criado_por BIGINT NOT NULL REFERENCES seguranca.utilizadores(utilizador_id) ON DELETE RESTRICT,
  ativo BOOLEAN NOT NULL DEFAULT TRUE, criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (email=lower(trim(email)) AND email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
);
ALTER TABLE seguranca.utilizadores ADD CONSTRAINT utilizadores_supervisor_fk
  FOREIGN KEY (supervisor_id) REFERENCES estagios.supervisores(supervisor_id) ON DELETE RESTRICT;
CREATE TABLE estagios.estagiarios (
  estagiario_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  supervisor_id BIGINT NOT NULL REFERENCES estagios.supervisores(supervisor_id) ON DELETE RESTRICT,
  nome VARCHAR(120) NOT NULL CHECK (length(trim(nome)) BETWEEN 2 AND 120),
  email VARCHAR(254) NOT NULL,
  telefone VARCHAR(9) NOT NULL CHECK (telefone ~ '^[0-9]{9}$'),
  instituicao VARCHAR(150) NOT NULL, ativo BOOLEAN NOT NULL DEFAULT TRUE,
  estado VARCHAR(30) NOT NULL DEFAULT 'Em andamento' CHECK (estado IN ('Em andamento','Concluído contratado','Concluído não contratado')),
  criado_por BIGINT NOT NULL REFERENCES seguranca.utilizadores(utilizador_id) ON DELETE RESTRICT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now(), actualizado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (email=lower(trim(email)) AND email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
);

-- Recrutamento existente na aplicação: candidatos, vagas e associações a vagas.
CREATE TABLE recrutamento.vagas (
  vaga_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  titulo VARCHAR(150) NOT NULL CHECK (length(trim(titulo)) BETWEEN 3 AND 150),
  descricao VARCHAR(3000) NOT NULL, requisitos VARCHAR(2000),
  data_abertura DATE NOT NULL,
  estado VARCHAR(15) NOT NULL DEFAULT 'Aberta' CHECK (estado IN ('Aberta','Encerrada','Suspensa')), ativo BOOLEAN NOT NULL DEFAULT TRUE,
  criado_por BIGINT NOT NULL REFERENCES seguranca.utilizadores(utilizador_id) ON DELETE RESTRICT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now(), actualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE recrutamento.candidatos (
  candidato_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome VARCHAR(120) NOT NULL CHECK (length(trim(nome)) BETWEEN 2 AND 120),
  email VARCHAR(254) NOT NULL,
  telefone VARCHAR(9) NOT NULL CHECK (telefone ~ '^[0-9]{9}$'),
  formacao VARCHAR(150) NOT NULL, ativo BOOLEAN NOT NULL DEFAULT TRUE,
  criado_por BIGINT NOT NULL REFERENCES seguranca.utilizadores(utilizador_id) ON DELETE RESTRICT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now(), actualizado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (email=lower(trim(email)) AND email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
);
-- Associação normalizada candidato-vaga para validar referências com FK.
CREATE TABLE recrutamento.candidato_vagas (
  candidato_id BIGINT NOT NULL REFERENCES recrutamento.candidatos(candidato_id) ON DELETE RESTRICT,
  vaga_id BIGINT NOT NULL REFERENCES recrutamento.vagas(vaga_id) ON DELETE RESTRICT,
  ativo BOOLEAN NOT NULL DEFAULT TRUE, PRIMARY KEY(candidato_id,vaga_id)
);

-- Estados de prazo são derivados da data. A data limite original não pode ser adulterada após vencer.
CREATE FUNCTION juridico.estado_prazo(p_limite DATE,p_entrega DATE) RETURNS VARCHAR(30)
LANGUAGE SQL STABLE AS $$ SELECT CASE
 WHEN p_entrega IS NOT NULL AND p_entrega<=p_limite THEN 'Entregue no prazo'
 WHEN p_entrega IS NOT NULL THEN 'Entregue fora do prazo'
 WHEN p_limite<CURRENT_DATE THEN 'Vencido'
 WHEN p_limite<=CURRENT_DATE+3 THEN 'Próximo' ELSE 'Dentro do prazo' END $$;
CREATE FUNCTION juridico.validar_prazo() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.data_entrega IS NOT NULL AND NEW.data_entrega>CURRENT_DATE THEN RAISE EXCEPTION 'A data de entrega não pode ser futura'; END IF;
 IF NEW.data_entrega>NEW.data_limite AND length(trim(coalesce(NEW.nota_atraso,'')))=0 THEN RAISE EXCEPTION 'A entrega atrasada exige nota justificativa'; END IF;
 IF TG_OP='UPDATE' AND OLD.data_limite<CURRENT_DATE THEN
   IF NEW.processo_id IS DISTINCT FROM OLD.processo_id OR NEW.descricao IS DISTINCT FROM OLD.descricao OR NEW.data_limite IS DISTINCT FROM OLD.data_limite OR NEW.criado_por IS DISTINCT FROM OLD.criado_por THEN RAISE EXCEPTION 'Prazo vencido bloqueado; registe apenas entrega e nota'; END IF;
   IF OLD.data_entrega IS NOT NULL AND NEW.data_entrega IS DISTINCT FROM OLD.data_entrega THEN RAISE EXCEPTION 'A data real de entrega já foi registada'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER prazo_validacao BEFORE INSERT OR UPDATE ON juridico.prazos FOR EACH ROW EXECUTE FUNCTION juridico.validar_prazo();

-- Auditoria automática; nunca grava senha_hash.
CREATE FUNCTION seguranca.auditar() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE antigo JSONB; novo JSONB; linha JSONB; rid BIGINT; uid BIGINT;
BEGIN
 uid:=NULLIF(current_setting('app.user_id',true),'')::BIGINT;
 IF TG_OP='INSERT' THEN linha:=to_jsonb(NEW); novo:=linha; antigo:=NULL;
 ELSIF TG_OP='UPDATE' THEN linha:=to_jsonb(NEW); novo:=linha; antigo:=to_jsonb(OLD);
 ELSE linha:=to_jsonb(OLD); antigo:=linha; novo:=NULL; END IF;
 IF TG_TABLE_NAME='utilizadores' THEN antigo:=antigo-'senha_hash'; novo:=novo-'senha_hash'; END IF;
 rid:=NULLIF(linha->>TG_ARGV[0],'')::BIGINT;
 INSERT INTO seguranca.auditoria(utilizador_id,perfil_no_momento,tabela,registo_id,operacao,antes,depois)
 VALUES(uid,NULLIF(current_setting('app.perfil',true),''),TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME,rid,TG_OP,antigo,novo);
 RETURN NEW;
END $$;
CREATE TRIGGER audit_clientes AFTER INSERT OR UPDATE ON juridico.clientes FOR EACH ROW EXECUTE FUNCTION seguranca.auditar('cliente_id');
CREATE TRIGGER audit_processos AFTER INSERT OR UPDATE ON juridico.processos FOR EACH ROW EXECUTE FUNCTION seguranca.auditar('processo_id');
CREATE TRIGGER audit_prazos AFTER INSERT OR UPDATE ON juridico.prazos FOR EACH ROW EXECUTE FUNCTION seguranca.auditar('prazo_id');
CREATE TRIGGER audit_supervisores AFTER INSERT OR UPDATE ON estagios.supervisores FOR EACH ROW EXECUTE FUNCTION seguranca.auditar('supervisor_id');
CREATE TRIGGER audit_estagiarios AFTER INSERT OR UPDATE ON estagios.estagiarios FOR EACH ROW EXECUTE FUNCTION seguranca.auditar('estagiario_id');
CREATE TRIGGER audit_candidatos AFTER INSERT OR UPDATE ON recrutamento.candidatos FOR EACH ROW EXECUTE FUNCTION seguranca.auditar('candidato_id');
CREATE TRIGGER audit_vagas AFTER INSERT OR UPDATE ON recrutamento.vagas FOR EACH ROW EXECUTE FUNCTION seguranca.auditar('vaga_id');
CREATE TRIGGER audit_utilizadores AFTER INSERT OR UPDATE ON seguranca.utilizadores FOR EACH ROW EXECUTE FUNCTION seguranca.auditar('utilizador_id');
CREATE TRIGGER audit_perfis AFTER INSERT OR UPDATE ON seguranca.perfis FOR EACH ROW EXECUTE FUNCTION seguranca.auditar('perfil_id');
CREATE TRIGGER audit_permissoes_perfil AFTER INSERT OR UPDATE ON seguranca.permissoes_perfil FOR EACH ROW EXECUTE FUNCTION seguranca.auditar('perfil_id');
CREATE TRIGGER audit_permissoes_utilizador AFTER INSERT OR UPDATE ON seguranca.permissoes_utilizador FOR EACH ROW EXECUTE FUNCTION seguranca.auditar('utilizador_id');

-- Defesa em profundidade: nenhuma tabela de dados permite DELETE ou TRUNCATE.
-- A aplicação altera ativo; nem Administrador pode remover fisicamente registos.
CREATE FUNCTION seguranca.impedir_eliminacao() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Eliminação permanente bloqueada. Marque o registo como inactivo.'; END $$;
DO $$ DECLARE t TEXT; BEGIN
 FOREACH t IN ARRAY ARRAY[
  'seguranca.perfis','seguranca.utilizadores','seguranca.permissoes_perfil','seguranca.permissoes_utilizador','seguranca.auditoria',
  'juridico.clientes','juridico.processos','juridico.prazos',
  'estagios.supervisores','estagios.estagiarios',
  'recrutamento.candidatos','recrutamento.vagas','recrutamento.candidato_vagas'
 ] LOOP
  EXECUTE format('CREATE TRIGGER bloquear_eliminacao BEFORE DELETE OR TRUNCATE ON %s FOR EACH STATEMENT EXECUTE FUNCTION seguranca.impedir_eliminacao()',t);
 END LOOP;
END $$;

-- Views usam JOINs aplicáveis aos relatórios; a aplicação continua responsável por filtrar por perfil.
CREATE VIEW relatorios.prazos_acompanhamento AS
 SELECT z.prazo_id,z.descricao,z.data_limite,z.data_entrega,juridico.estado_prazo(z.data_limite,z.data_entrega) estado,
 z.nota_atraso,z.ativo prazo_ativo,p.processo_id,p.numero,p.tipo,p.ativo processo_ativo,
 c.cliente_id,c.nome cliente,c.ativo cliente_ativo,f.utilizador_id,f.nome registado_por,f.ativo utilizador_ativo
 FROM juridico.prazos z JOIN juridico.processos p USING(processo_id)
 JOIN juridico.clientes c USING(cliente_id) JOIN seguranca.utilizadores f ON f.utilizador_id=z.criado_por;
CREATE VIEW relatorios.estagios_activos AS
 SELECT e.estagiario_id,e.nome estagiario,e.estado,s.supervisor_id,s.nome supervisor,e.instituicao
 FROM estagios.estagiarios e JOIN estagios.supervisores s USING(supervisor_id) WHERE e.estado='Em andamento' AND e.ativo AND s.ativo;
CREATE VIEW relatorios.candidatos_vagas AS
 SELECT c.candidato_id,c.nome candidato,c.ativo candidato_ativo,cv.ativo associacao_ativa,
 v.vaga_id,v.titulo vaga,v.ativo vaga_ativa
 FROM recrutamento.candidato_vagas cv JOIN recrutamento.candidatos c USING(candidato_id) JOIN recrutamento.vagas v USING(vaga_id);

-- Índices para filtros, relações e pesquisa.
CREATE INDEX clientes_criador_idx ON juridico.clientes(criado_por);
CREATE INDEX clientes_nome_idx ON juridico.clientes(lower(nome));
CREATE INDEX processos_cliente_idx ON juridico.processos(cliente_id);
CREATE INDEX processos_criador_idx ON juridico.processos(criado_por);
CREATE INDEX prazos_limite_idx ON juridico.prazos(data_limite);
CREATE INDEX prazos_processo_idx ON juridico.prazos(processo_id);
CREATE INDEX prazos_criador_idx ON juridico.prazos(criado_por);
CREATE INDEX estagiarios_supervisor_idx ON estagios.estagiarios(supervisor_id);
CREATE INDEX estagiarios_criador_idx ON estagios.estagiarios(criado_por);
CREATE INDEX candidatos_nome_idx ON recrutamento.candidatos(lower(nome));
CREATE INDEX vagas_estado_idx ON recrutamento.vagas(estado);
CREATE INDEX auditoria_data_idx ON seguranca.auditoria(ocorrido_em DESC);
CREATE INDEX clientes_ativos_idx ON juridico.clientes(cliente_id) WHERE ativo;
CREATE INDEX processos_ativos_idx ON juridico.processos(processo_id) WHERE ativo;
CREATE INDEX prazos_ativos_idx ON juridico.prazos(prazo_id) WHERE ativo;
CREATE INDEX estagiarios_ativos_idx ON estagios.estagiarios(estagiario_id) WHERE ativo;
CREATE INDEX candidatos_ativos_idx ON recrutamento.candidatos(candidato_id) WHERE ativo;
CREATE INDEX vagas_ativas_idx ON recrutamento.vagas(vaga_id) WHERE ativo;

-- Perfis iniciais; utilizadores são criados pela interface depois de integrar autenticação com PostgreSQL.
INSERT INTO seguranca.perfis(codigo,descricao) VALUES
 ('Administrador','Gere contas, permissões e todos os módulos.'),
 ('Gestor','Gere os seus registos e consulta os registos dos Funcionários.'),
 ('Funcionário','Regista clientes, processos e prazos próprios.'),
 ('Supervisor','Gere os estagiários que criou.')
ON CONFLICT(codigo) DO NOTHING;

-- Permissões de base; a aplicação aplica também o âmbito por registo.
INSERT INTO seguranca.permissoes_perfil(perfil_id,modulo,accao)
SELECT p.perfil_id,x.modulo,x.accao FROM seguranca.perfis p JOIN (VALUES
 ('Administrador','dashboard','ver'),('Administrador','clientes','ver'),('Administrador','clientes','criar'),('Administrador','clientes','editar'),('Administrador','processos','ver'),('Administrador','processos','criar'),('Administrador','processos','editar'),('Administrador','supervisores','ver'),('Administrador','supervisores','criar'),('Administrador','supervisores','editar'),('Administrador','estagiarios','ver'),('Administrador','estagiarios','criar'),('Administrador','estagiarios','editar'),('Administrador','candidatos','ver'),('Administrador','candidatos','criar'),('Administrador','candidatos','editar'),('Administrador','vagas','ver'),('Administrador','vagas','criar'),('Administrador','vagas','editar'),('Administrador','prazos','ver'),('Administrador','prazos','criar'),('Administrador','prazos','editar'),('Administrador','utilizadores','ver'),('Administrador','utilizadores','criar'),('Administrador','utilizadores','editar'),('Administrador','relatorios','ver'),('Administrador','configuracoes','ver'),('Administrador','configuracoes','editar'),
 ('Gestor','dashboard','ver'),('Gestor','clientes','ver'),('Gestor','clientes','criar'),('Gestor','clientes','editar'),('Gestor','processos','ver'),('Gestor','processos','criar'),('Gestor','processos','editar'),('Gestor','candidatos','ver'),('Gestor','candidatos','criar'),('Gestor','candidatos','editar'),('Gestor','vagas','ver'),('Gestor','vagas','criar'),('Gestor','vagas','editar'),('Gestor','prazos','ver'),('Gestor','prazos','criar'),('Gestor','prazos','editar'),('Gestor','relatorios','ver'),('Gestor','configuracoes','ver'),('Gestor','configuracoes','editar'),
 ('Funcionário','dashboard','ver'),('Funcionário','clientes','ver'),('Funcionário','clientes','criar'),('Funcionário','clientes','editar'),('Funcionário','processos','ver'),('Funcionário','processos','criar'),('Funcionário','processos','editar'),('Funcionário','prazos','ver'),('Funcionário','prazos','criar'),('Funcionário','prazos','editar'),('Funcionário','configuracoes','ver'),('Funcionário','configuracoes','editar'),
 ('Supervisor','dashboard','ver'),('Supervisor','supervisores','ver'),('Supervisor','estagiarios','ver'),('Supervisor','estagiarios','criar'),('Supervisor','estagiarios','editar'),('Supervisor','configuracoes','ver'),('Supervisor','configuracoes','editar')
) AS x(perfil,modulo,accao) ON p.codigo=x.perfil ON CONFLICT DO NOTHING;

-- A aplicação liga com sigj_app, nunca com o utilizador proprietário/superuser.
-- sigj_app não recebe DELETE, TRUNCATE, CREATE, ALTER ou DROP.
GRANT CONNECT ON DATABASE gestao_juridica_integrada TO sigj_app;
GRANT USAGE ON SCHEMA seguranca,juridico,estagios,recrutamento,relatorios TO sigj_app;
GRANT SELECT,INSERT,UPDATE ON ALL TABLES IN SCHEMA seguranca,juridico,estagios,recrutamento TO sigj_app;
GRANT SELECT ON ALL TABLES IN SCHEMA relatorios TO sigj_app;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA seguranca,juridico,estagios,recrutamento TO sigj_app;
REVOKE DELETE,TRUNCATE ON ALL TABLES IN SCHEMA seguranca,juridico,estagios,recrutamento,relatorios FROM sigj_app;
REVOKE UPDATE ON seguranca.auditoria FROM sigj_app;
ALTER DEFAULT PRIVILEGES FOR ROLE sigj_dba IN SCHEMA seguranca,juridico,estagios,recrutamento GRANT SELECT,INSERT,UPDATE ON TABLES TO sigj_app;
ALTER DEFAULT PRIVILEGES FOR ROLE sigj_dba IN SCHEMA seguranca,juridico,estagios,recrutamento GRANT USAGE,SELECT ON SEQUENCES TO sigj_app;

-- Exemplos DML/DQL a executar pela aplicação com parâmetros preparados:
-- INSERT INTO juridico.clientes(nome,email,telefone,criado_por) VALUES ($1,$2,$3,$4) RETURNING cliente_id;
-- UPDATE juridico.prazos SET data_entrega=$1,nota_atraso=$2 WHERE prazo_id=$3;
-- SELECT * FROM relatorios.prazos_acompanhamento WHERE prazo_ativo=TRUE ORDER BY data_limite;
-- UPDATE juridico.clientes SET ativo=FALSE WHERE cliente_id=$1; -- inativar sem apagar
-- UPDATE juridico.clientes SET ativo=TRUE WHERE cliente_id=$1; -- reactivar
-- SELECT * FROM juridico.clientes WHERE ativo=FALSE; -- usar apenas quando o filtro Inactivos for escolhido
-- BEGIN; UPDATE juridico.processos SET estado=$1 WHERE processo_id=$2; COMMIT; -- ou ROLLBACK
-- ALTER TABLE juridico.clientes ADD COLUMN observacao VARCHAR(500); -- exemplo de evolução
-- DROP: não usar DROP TABLE, DELETE ou TRUNCATE para remover dados; use ativo=FALSE.

COMMIT;

/* Backup/restore no host:
 docker compose exec -T db pg_dump -U sigj_dba gestao_juridica_integrada > backup.sql
 docker compose exec -T db psql -U sigj_dba -d gestao_juridica_integrada < backup.sql
*/







