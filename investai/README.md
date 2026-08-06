# InvestAI

Repositório do projeto **InvestAI**, um assistente financeiro que orienta usuários
iniciantes e intermediários. O projeto está dividido em `frontend` (interface web) e
`backend` (API em Flask), implementando o CRUD básico das Models do domínio e,
além disso, um conjunto de **funcionalidades avançadas** (consultas com filtros,
ordenações, JOINs entre tabelas e relatórios) encapsuladas na camada **Repository**.

## Estrutura do repositório

```
investai/
├── frontend/                      → interface web (HTML, CSS e JavaScript)
│   ├── index.html
│   ├── usuarios.html / usuario_form.html
│   ├── movimentacoes.html / movimentacao_form.html
│   ├── investimentos.html / investimento_form.html
│   ├── metas.html / meta_form.html
│   ├── relatorio.html             → dashboard com relatório financeiro e busca de usuários
│   ├── css/estilo.css
│   └── js/api.js
└── backend/                       → API Web em Flask
    ├── app.py
    ├── requirements.txt
    ├── controllers/               → recebem as requisições da API e retornam respostas
    ├── models/                    → entidades e operações básicas do banco (CRUD)
    ├── repositories/              → consultas específicas que vão além do CRUD básico
    ├── services/                  → casos de uso e regras da aplicação
    └── database/
        └── create_database.sql    → script de criação do banco e tabelas
```

## Arquitetura

O backend segue quatro camadas:

- **Controllers** — recebem as requisições HTTP (Blueprints do Flask) e devolvem JSON.
- **Services** — implementam os casos de uso, um método por funcionalidade, chamando
  a Model (CRUD básico) ou o Repository (consultas avançadas).
- **Models** — representam as entidades do domínio e o CRUD básico (herdando de
  `ModeloBase`, que usa Flask-SQLAlchemy).
- **Repositories** — concentram consultas específicas que vão além do CRUD básico:
  filtros (`WHERE`), buscas (`LIKE`), ordenações (`ORDER BY`), junções entre tabelas
  (`JOIN`) e agregações (`SUM`/`COUNT`), escritas com SQLAlchemy na camada de acesso
  a dados.

O frontend consome essas rotas por meio de chamadas `fetch` centralizadas em
`js/api.js` (funções `apiListar`, `apiBuscar`, `apiCriar`, `apiAtualizar`,
`apiExcluir` para o CRUD, e `apiGet` para as consultas avançadas com parâmetros).

## Models implementadas

- **Usuario** — nome, email, perfil_risco, renda_mensal. Entidade central.
- **Movimentacao** — descricao, tipo (renda/gasto), valor, data. Chave estrangeira para Usuario.
- **Investimento** — nome, tipo, valor_aplicado, rendimento_atual, liquidez. Chave estrangeira para Usuario.
- **Meta** — titulo, valor_alvo, valor_atual, prazo, com progresso calculado. Chave estrangeira para Usuario.

Todas herdam de `ModeloBase`, que fornece os métodos de criar (`salvar`), listar,
buscar, atualizar e deletar (CRUD básico).

## Repositories e consultas avançadas implementadas

Cada Repository concentra o acesso a dados que vai além do CRUD básico:

| Repository | Método | Consulta | Descrição |
|---|---|---|---|
| `UsuarioRepository` | `buscar_com_estatisticas(termo)` | `LIKE` + `JOIN` (3 tabelas) + `GROUP BY` + `ORDER BY` | Busca usuários por nome/e-mail e retorna, para cada um, a quantidade de movimentações, investimentos, metas e o total investido. |
| `UsuarioRepository` | `relatorio_financeiro(usuario_id)` | Agregações (`SUM`/`COUNT`) combinando Usuario + Movimentacao + Investimento + Meta | Relatório consolidado: total de rendas, total de gastos, saldo, total investido, rendimento total, patrimônio total e progresso das metas. |
| `UsuarioRepository` | `listar_por_perfil(perfil_risco)` | `WHERE` + `ORDER BY` | Lista usuários filtrados por perfil de risco. |
| `MovimentacaoRepository` | `extrato(usuario_id, tipo, data_inicio, data_fim, ordenar)` | `WHERE` combinável (tipo e intervalo de datas) + `ORDER BY` configurável | Extrato de movimentações do usuário com filtros e ordenação. |
| `InvestimentoRepository` | `ranking_por_rendimento(usuario_id, limite, tipo)` | `WHERE` + `ORDER BY ... DESC` + `LIMIT` | Ranking dos investimentos do usuário com maior rendimento atual. |
| `MetaRepository` | `listar_por_status(usuario_id, status)` | `WHERE` (comparação `valor_atual` x `valor_alvo`) + `ORDER BY` | Lista metas do usuário filtradas por status (concluída / em andamento), ordenadas por prazo. |

## Rotas da API

### CRUD básico (por Model)

Troque `<recurso>` por `usuarios`, `movimentacoes`, `investimentos` ou `metas`:

| Método | Rota | Ação |
|--------|------|------|
| GET | `/api/<recurso>` | Listar todos |
| GET | `/api/<recurso>/<id>` | Buscar por id |
| POST | `/api/<recurso>` | Criar |
| PUT | `/api/<recurso>/<id>` | Atualizar |
| DELETE | `/api/<recurso>/<id>` | Excluir |

### Funcionalidades avançadas (Repository + procedures de consulta)

| Método | Rota | Query params | Ação |
|--------|------|---------------|------|
| GET | `/api/usuarios/busca` | `termo` (opcional) | Busca usuários por nome/e-mail com estatísticas agregadas (JOIN). |
| GET | `/api/usuarios/perfil/<perfil_risco>` | — | Lista usuários por perfil de risco. |
| GET | `/api/usuarios/<id>/relatorio` | — | Relatório financeiro consolidado do usuário. |
| GET | `/api/movimentacoes/extrato/<usuario_id>` | `tipo`, `data_inicio`, `data_fim`, `ordenar` | Extrato filtrado e ordenável de movimentações. |
| GET | `/api/investimentos/ranking/<usuario_id>` | `limite`, `tipo` | Ranking de investimentos por rendimento. |
| GET | `/api/metas/status/<usuario_id>` | `status` (`concluida` \| `em_andamento`) | Metas filtradas por status, ordenadas por prazo. |

## Funcionalidades (telas)

- **Usuários** — CRUD completo + filtro por perfil de risco.
- **Movimentações** — CRUD completo + extrato com filtros (tipo, período) e ordenação (data/valor).
- **Investimentos** — CRUD completo + ranking por rendimento (com filtro por tipo e limite de itens).
- **Metas** — CRUD completo + abas de filtro por status (todas / em andamento / concluídas).
- **Relatório** (nova tela) — dashboard com o relatório financeiro consolidado do
  usuário selecionado e busca de usuários com estatísticas agregadas.

Cada tela chama as rotas correspondentes da API por meio de `js/api.js`.

## Como executar o projeto

### 1. Backend

```bash
cd backend
pip install -r requirements.txt
python app.py
```

A API sobe em `http://127.0.0.1:5000`. O banco SQLite (`investai.db`) é criado
automaticamente na primeira execução, já com as tabelas do domínio. O arquivo
`database/create_database.sql` traz o script equivalente para MySQL/MariaDB, caso o
grupo prefira rodar em um banco relacional completo (basta trocar
`SQLALCHEMY_DATABASE_URI` em `app.py`, por exemplo para
`mysql+pymysql://usuario:senha@localhost/investai`, e instalar o driver
`PyMySQL`).

### 2. Frontend

Com o backend rodando, sirva a pasta frontend com um servidor simples:

```bash
cd frontend
python -m http.server 5500
```

Depois acesse `http://127.0.0.1:5500`. O endereço da API pode ser ajustado na constante
`API_URL` em `frontend/js/api.js`.

## Tecnologias

Backend: Python, Flask, Flask-SQLAlchemy, Flask-Cors e SQLite (o SQL de produção é
voltado a MySQL/MariaDB). Frontend: HTML, CSS e JavaScript puro (fetch).
