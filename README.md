# InvestAI

Repositório do projeto **InvestAI**, um assistente financeiro que orienta usuários
iniciantes e intermediários. O projeto está dividido em `frontend` (interface web) e
`backend` (API em Flask), e implementa o CRUD completo das principais Models do domínio,
com telas para cadastrar, listar, editar e excluir os dados chamando as rotas da API.

## Estrutura do repositório

```
investai/
├── frontend/                      → interface web (HTML, CSS e JavaScript)
│   ├── index.html
│   ├── usuarios.html / usuario_form.html
│   ├── movimentacoes.html / movimentacao_form.html
│   ├── investimentos.html / investimento_form.html
│   ├── metas.html / meta_form.html
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

## Arquitetura (mesma nas duas partes)

O backend segue quatro camadas. Os **controllers** recebem as requisições e retornam
JSON; os **services** implementam os casos de uso; as **models** representam as
entidades e o CRUD básico (herdando de `Model` do SQLAlchemy); e os **repositories**
concentram consultas específicas, como saldo do usuário e total aplicado. O frontend
consome essas rotas por meio de chamadas `fetch` centralizadas em `js/api.js`.

## Models implementadas

Baseadas na modelagem de domínio já entregue do InvestAI:

- **Usuario** — nome, email, perfil_risco, renda_mensal. Entidade central.
- **Movimentacao** — descricao, tipo (renda/gasto), valor, data. Chave estrangeira para Usuario.
- **Investimento** — nome, tipo, valor_aplicado, rendimento_atual, liquidez. Chave estrangeira para Usuario.
- **Meta** — titulo, valor_alvo, valor_atual, prazo, com progresso calculado. Chave estrangeira para Usuario.

Todas herdam de `ModeloBase`, que fornece os métodos de criar (`salvar`), listar,
buscar, atualizar e deletar.

## Rotas da API (CRUD por Model)

Troque `<recurso>` por `usuarios`, `movimentacoes`, `investimentos` ou `metas`:

| Método | Rota | Ação |
|--------|------|------|
| GET | `/api/<recurso>` | Listar todos |
| GET | `/api/<recurso>/<id>` | Buscar por id |
| POST | `/api/<recurso>` | Criar |
| PUT | `/api/<recurso>/<id>` | Atualizar |
| DELETE | `/api/<recurso>/<id>` | Excluir |

## Funcionalidades (telas)

Para cada Model existem telas de listagem e de formulário (cadastrar e editar no mesmo
arquivo), além da exclusão com confirmação. Cada tela chama as rotas CRUD da API.

## Como executar o projeto

### 1. Backend

```bash
cd backend
pip install -r requirements.txt
python app.py
```

A API sobe em `http://127.0.0.1:5000`. O banco SQLite (`investai.db`) é criado
automaticamente na primeira execução. O arquivo `database/create_database.sql` traz o
script equivalente para MySQL/MariaDB.

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
