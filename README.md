# SIGJ — Sistema Integrado de Gestão de Jovens

Aplicação PHP com autenticação, permissões por perfil e operações de consulta, criação, edição e inativação para as entidades atuais. Os registos ficam temporariamente num ficheiro JSON fora da pasta pública do projecto; a camada de repositório está isolada para futura substituição por uma base de dados.

## Iniciar com Docker

Com Docker Desktop em execução, no terminal aberto nesta pasta:

```powershell
Copy-Item .env.example .env
docker compose up --build
```

Abra http://localhost:8080. Para parar, use `Ctrl+C` e depois `docker compose down`. Os dados JSON de demonstração ficam num volume Docker; o PostgreSQL também tem volume persistente.

O contentor PostgreSQL separa a conta de manutenção `sigj_dba` da conta da aplicação `sigj_app`. A aplicação nunca usa a conta de manutenção. Depois de aplicado o esquema, a conta da aplicação não terá privilégios de `DELETE` ou `TRUNCATE`, e os triggers também rejeitam essas operações. O contentor PHP ainda usa o repositório JSON; o esquema em `database/schema_postgresql_review.sql` é uma proposta e não é carregado automaticamente.

## Contas iniciais

As contas iniciais usam a palavra-passe `Sigj@2026`:

- Administrador: `admin@sigj.ao`
- Gestor: `gestor@sigj.ao`
- Supervisor: `teresa.neto@sigj.ao` (Teresa Neto)

O perfil Funcionário está disponível para contas criadas pelo Administrador. Altere a palavra-passe após o primeiro acesso. A redefinição é feita pelo Administrador porque ainda não há serviço de e-mail ligado. As palavras-passe ficam guardadas com hash. A aplicação inclui sessão, protecção CSRF, validação e controlo de permissões no servidor.

## Perfis e permissões

- **Administrador:** acesso total; cria e altera utilizadores, escolhe o perfil e as permissões de cada conta; é o único que pode criar ou alterar registos de supervisores.
- **Gestor:** gere os seus clientes, processos, candidatos, vagas e prazos. Também consulta clientes, processos e prazos registados pelos Funcionários, identificados pelo nome e ID; esses registos só podem ser editados pelo Funcionário criador ou pelo Administrador.
- **Funcionário:** regista clientes e os respectivos processos e prazos. Consulta e edita apenas os registos da sua conta. O Gestor consegue consultá-los e ver quem os registou.
- **Supervisor:** cria estagiários e consulta ou edita os que criou; cada estagiário fica associado ao supervisor criador. Pode actualizar a situação do estágio para Em andamento, Concluído contratado ou Concluído não contratado. O Administrador pode definir permissões adicionais, mantendo o âmbito de registos do próprio utilizador.

Os registos não são apagados: podem ser marcados como activos ou inactivos. As listas e relatórios mostram apenas activos por padrão; use o filtro de situação para consultar inactivos ou todos. A desactivação preserva os dados e as relações.

O estado dos prazos é calculado pela data limite: fica “Próximo” nos três dias anteriores e “Vencido” depois da data. Quando a data limite passa, ela e os restantes dados do prazo ficam bloqueados; o utilizador pode registar a data real de entrega e a nota do atraso. A entrega fica marcada como “Entregue fora do prazo”, sem apagar o vencimento original.

O Administrador configura as permissões por módulo e por acção (ver, criar e editar) na ficha do utilizador. Nenhum perfil, incluindo Administrador, elimina registos. O acesso a registos é sempre filtrado no servidor pela conta proprietária; alterar o endereço de uma página não dá acesso aos registos de outra conta.

## Fotografias

O login usa fotografias reais de profissionais jurídicos do Pexels, guardadas localmente para o ecrã não depender de uma ligação à Internet. Pexels indica que as fotografias são gratuitas e podem ser modificadas. Créditos: [Sora Shimazaki](https://www.pexels.com/photo/female-lawyers-in-an-office-looking-at-a-computer-4427553/) e [August de Richelieu](https://www.pexels.com/photo/lawyers-in-an-office-4427422/). Consulte a [licença Pexels](https://www.pexels.com/license/).

A camada de armazenamento JSON destina-se ao desenvolvimento local. A migração para base de dados será feita substituindo o repositório, sem reescrever os ecrãs e fluxos da aplicação.




