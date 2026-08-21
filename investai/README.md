# InvestAI

Repositório do projeto **InvestAI**, um assistente financeiro que guia o usuário desde
o controle básico de gastos até recomendações de investimento por perfil de risco —
só liberando sugestões de investimento depois que ele forma uma reserva de emergência
equivalente a 3 meses de despesas. O projeto está dividido em `backend` (API em Flask,
com autenticação JWT) e `frontend_flutter` (app mobile em Flutter), implementando os
20 requisitos funcionais (RF01–RF20) do relatório de elicitação de requisitos.

## Estrutura do repositório

```
investai/
├── frontend_flutter/               → app mobile em Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── theme.dart
│   │   ├── models/                 → Usuario, Movimentacao, Meta, Investimento, LimiteCategoria
│   │   ├── services/api_service.dart → cliente HTTP autenticado (JWT) para a API
│   │   └── screens/
│   │       ├── splash_screen.dart / login_screen.dart / cadastro_screen.dart
│   │       ├── home_screen.dart    → shell com navegação em abas
│   │       ├── dashboard_tab.dart  → Início (saldo, economia, sobrevivência, guia)
│   │       ├── report_tab.dart     → Relatório (gráfico por categoria, alertas, histórico)
│   │       ├── metas_tab.dart      → Metas (progresso, reserva de emergência, aportes)
│   │       ├── investimentos_tab.dart → Investir (score, carteira, sugestões)
│   │       └── perfil_tab.dart     → Perfil (perfil de investidor, limites, logout)
│   └── pubspec.yaml
└── backend/                        → API Web em Flask
    ├── app.py
    ├── requirements.txt
    ├── controllers/                → Blueprints: recebem requisições e chamam as Services
    ├── models/                     → entidades e CRUD básico (Flask-SQLAlchemy)
    ├── repositories/                → consultas específicas que vão além do CRUD básico
    ├── services/                   → uma classe por funcionalidade, agrupadas por Model
    │   ├── usuario/                → CriarUsuarioService, AutenticarUsuarioService, ...
    │   ├── movimentacao/           → CriarMovimentacaoService, CalcularSaldoService, ...
    │   ├── meta/                   → CriarMetaService, CalcularStatusReservaEmergenciaService, ...
    │   ├── investimento/           → CriarInvestimentoService, ListarRankingInvestimentosService, ...
    │   └── limite_categoria/       → DefinirLimiteCategoriaService, ...
    └── database/
        └── create_database.sql     → script de criação do banco e tabelas
```

## Arquitetura

O backend segue quatro camadas:

- **Controllers** (Blueprints do Flask) — recebem as requisições HTTP e chamam a
  Service correspondente. As rotas de dados financeiros exigem um token JWT
  (`Authorization: Bearer <token>`) e operam sempre sobre o usuário autenticado, nunca
  sobre um `usuario_id` informado pelo cliente.
- **Services** — cada funcionalidade é uma classe própria, em um arquivo próprio (ex.:
  `CriarMovimentacaoService`, `CalcularSaldoService`), agrupadas em pastas por Model
  (`services/usuario/`, `services/movimentacao/`, ...). Toda Service expõe um método
  de instância `executar(...)`, que usa a Model (CRUD básico) ou o Repository
  (consultas avançadas) e já devolve o resultado pronto para virar JSON — a Controller
  só chama `MinhaService().executar(...)` e faz `jsonify(...)`. Erros de validação são
  `ValueError` (a Controller devolve 400); `services/erros.py` traz o
  `ErroAutenticacao` usado no login (401).
- **Models** — representam as entidades do domínio e o CRUD básico, herdando de
  `ModeloBase` (Flask-SQLAlchemy).
- **Repositories** — concentram consultas específicas que vão além do CRUD: filtros
  (`WHERE`), agregações (`SUM`/`GROUP BY`), ordenações (`ORDER BY`) e junções (`JOIN`).

O app Flutter consome essas rotas por meio do `ApiService`, que guarda o token JWT
localmente (`shared_preferences`) e o envia em toda chamada autenticada.

## Models implementadas

- **Usuario** — nome, email, senha (hash), perfil_risco, renda_mensal.
- **Movimentacao** — descricao, tipo (renda/gasto), valor, data, categoria. FK para Usuario.
- **Investimento** — nome, tipo, valor_aplicado, rendimento_atual, liquidez. FK para Usuario.
- **Meta** — titulo, valor_alvo, valor_atual, prazo, tipo (`geral` ou
  `reserva_emergencia`), com progresso calculado. FK para Usuario.
- **LimiteCategoria** — categoria, valor_limite (limite de gasto mensal por categoria). FK para Usuario.
- **TokenRevogado** — registra tokens JWT invalidados por logout, para um logout seguro de verdade.

Todas (exceto `TokenRevogado`) herdam de `ModeloBase`, que fornece criar (`salvar`),
listar, buscar, atualizar e deletar.

## Repositories e consultas avançadas

| Repository | Método | Descrição |
|---|---|---|
| `MovimentacaoRepository` | `extrato(...)` | Histórico filtrado por tipo, categoria e período, com ordenação configurável (RF19). |
| `MovimentacaoRepository` | `gastos_por_categoria(...)` | Soma de gastos agrupada por categoria — `GROUP BY` (RF11). |
| `MovimentacaoRepository` | `media_gastos_mensais(...)` | Média de gastos dos últimos meses, base da reserva de emergência e da sobrevivência sem renda (RF09/RF14/RF15). |
| `MovimentacaoRepository` | `resumo_mensal(...)` | Total de entradas, saídas e saldo de um mês/ano (RF10). |
| `MovimentacaoRepository` | `ultima_data_movimentacao(...)` | Data do último gasto, base do alerta de inatividade (RF12). |
| `MetaRepository` | `buscar_reserva_emergencia(...)` | Meta especial que representa a reserva de emergência do usuário (RF14/RF15). |
| `MetaRepository` | `listar_por_status(...)` | Metas filtradas por status (concluída / em andamento), ordenadas por prazo. |
| `InvestimentoRepository` | `ranking_por_rendimento(...)` | Ranking dos investimentos por rendimento — `ORDER BY ... LIMIT`. |
| `UsuarioRepository` | `buscar_com_estatisticas(...)` | Busca por nome/e-mail com estatísticas agregadas — `LIKE` + `JOIN` (3 tabelas). |
| `UsuarioRepository` | `relatorio_financeiro(...)` | Relatório consolidado combinando Usuario + Movimentacao + Investimento + Meta. |

## Rotas da API

Todas as rotas de `movimentacoes`, `metas`, `investimentos`, `limites` e `orientacao`
exigem `Authorization: Bearer <token>` e operam sobre o usuário autenticado.

### Autenticação e conta (RF01/RF02)

| Método | Rota | Ação |
|--------|------|------|
| POST | `/api/usuarios` | Criar conta (nome, e-mail, senha) |
| POST | `/api/usuarios/login` | Login (e-mail + senha), devolve token JWT |
| POST | `/api/usuarios/logout` | Logout seguro (revoga o token) |
| GET | `/api/usuarios/me` | Dados do usuário autenticado |
| PUT | `/api/usuarios/<id>` | Atualizar perfil de investidor / renda mensal (RF18) |

### Movimentações (RF03–RF05, RF08–RF13, RF19)

| Método | Rota | Ação |
|--------|------|------|
| GET / POST | `/api/movimentacoes` | Histórico com filtros (`tipo`, `categoria`, `data_inicio`, `data_fim`) / registrar receita ou despesa |
| PUT / DELETE | `/api/movimentacoes/<id>` | Atualizar / excluir |
| GET | `/api/movimentacoes/saldo` | Saldo disponível em tempo real (RF05) |
| GET | `/api/movimentacoes/capacidade-economia` | Capacidade de economia mensal (RF08) |
| GET | `/api/movimentacoes/sobrevivencia` | Tempo de sobrevivência sem renda (RF09) |
| GET | `/api/movimentacoes/relatorio-mensal` | Relatório financeiro mensal (RF10) |
| GET | `/api/movimentacoes/gastos-por-categoria` | Gastos agrupados por categoria (RF11) |
| GET | `/api/movimentacoes/alertas` | Alertas de inatividade e de limite por categoria (RF12/RF13) |

### Metas (RF06/RF07, RF14/RF15, RF17)

| Método | Rota | Ação |
|--------|------|------|
| GET / POST | `/api/metas` | Listar (com progresso e aporte sugerido) / criar meta |
| PUT / DELETE | `/api/metas/<id>` | Atualizar (ex.: registrar aporte) / excluir |
| GET | `/api/metas/status` | Metas filtradas por status |
| GET | `/api/metas/reserva-emergencia` | Status da reserva de emergência e se os investimentos já estão liberados |

### Investimentos, limites e orientação (RF13, RF16, RF20)

| Método | Rota | Ação |
|--------|------|------|
| GET / POST / PUT / DELETE | `/api/investimentos` | CRUD da carteira de investimentos |
| GET | `/api/investimentos/ranking` | Ranking por rendimento |
| GET / POST / DELETE | `/api/limites` | Limite de gasto mensal por categoria (RF13) |
| GET | `/api/orientacao/guia` | Guia financeiro passo a passo (RF16) |
| GET | `/api/orientacao/score` | Score financeiro, 0–1000 (RF20) |

## Requisitos funcionais implementados (RF01–RF20)

| RF | Descrição | Onde |
|---|---|---|
| RF01 | Criar conta (nome, e-mail, senha) | `services/usuario/criar_usuario_service.py` / tela de cadastro |
| RF02 | Login e logout seguros (JWT) | `services/usuario/autenticar_usuario_service.py`, `logout_usuario_service.py` |
| RF03/RF04 | Registrar receitas e despesas por categoria | `services/movimentacao/criar_movimentacao_service.py` / aba Relatório |
| RF05 | Saldo disponível em tempo real | `services/movimentacao/calcular_saldo_service.py` / aba Início |
| RF06/RF07 | Metas com progresso | `services/meta/criar_meta_service.py`, `listar_metas_service.py` / aba Metas |
| RF08 | Capacidade de economia mensal | `services/movimentacao/calcular_capacidade_economia_service.py` |
| RF09 | Tempo de sobrevivência sem renda | `services/movimentacao/calcular_sobrevivencia_service.py` |
| RF10 | Relatório financeiro mensal | `services/movimentacao/gerar_relatorio_mensal_service.py` |
| RF11 | Gráfico de gastos por categoria | `services/movimentacao/calcular_gastos_por_categoria_service.py` / aba Relatório |
| RF12 | Alerta de inatividade (3+ dias sem gasto) | `services/movimentacao/gerar_alertas_service.py` |
| RF13 | Alerta de limite por categoria | `services/limite_categoria/*` |
| RF14/RF15 | Reserva de emergência antes de liberar investimentos | `services/meta/calcular_status_reserva_emergencia_service.py` |
| RF16 | Guia financeiro passo a passo | `services/usuario/gerar_guia_financeiro_service.py` |
| RF17 | Aporte sugerido ajustado à capacidade de economia | `services/meta/listar_metas_service.py` |
| RF18 | Perfil de investidor (conservador/moderado/arrojado) | cadastro + aba Perfil |
| RF19 | Histórico com filtro por período e categoria | `services/movimentacao/listar_movimentacoes_service.py` / aba Relatório |
| RF20 | Score financeiro (0–1000) | `services/usuario/calcular_score_financeiro_service.py` |

## Funcionalidades (telas do app Flutter)

- **Início** — saldo em tempo real, economia do mês, tempo de sobrevivência, prévia
  das metas e o guia financeiro em destaque.
- **Metas** — criação e acompanhamento de metas com barra de progresso, reserva de
  emergência com aporte dedicado, e aporte mensal sugerido por meta.
- **Relatório** — gráfico de gastos por categoria, notificações de comportamento
  financeiro e histórico completo de transações com filtros.
- **Investir** — score financeiro, carteira de investimentos e sugestões
  personalizadas por perfil de risco, liberadas após a reserva de emergência.
- **Perfil** — perfil de investidor, limites de gasto por categoria e logout.

## Como executar o projeto

### 1. Backend

```bash
cd backend
pip install -r requirements.txt
python app.py
```

A API sobe em `http://127.0.0.1:5000`. O banco SQLite (`investai.db`) é criado
automaticamente na primeira execução. O arquivo `database/create_database.sql` traz o
script equivalente para MySQL/MariaDB. Defina a variável de ambiente `SECRET_KEY` em
produção (usada para assinar os tokens JWT).

### 2. Frontend (Flutter)

Com o backend rodando:

```bash
cd frontend_flutter
flutter pub get
flutter run
```

Ajuste `baseUrl` em `lib/services/api_service.dart` conforme o alvo: `localhost` para
Web/Desktop, `10.0.2.2` para emulador Android, ou o IP da máquina na rede local para um
dispositivo físico.

## Tecnologias

**Backend:** Python, Flask, Flask-SQLAlchemy, Flask-Cors, PyJWT, Werkzeug (hash de
senha) e SQLite (o SQL de produção é voltado a MySQL/MariaDB).

**Frontend:** Flutter/Dart, `http` (cliente da API), `shared_preferences` (sessão
local), `google_fonts`, `fl_chart` (gráficos).
