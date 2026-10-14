# InvestAI

Repositório do projeto **InvestAI**, um assistente financeiro que guia o usuário desde
o controle básico de gastos até recomendações de investimento por perfil de risco —
só liberando sugestões de investimento depois que ele forma uma reserva de emergência
equivalente a 3 meses de despesas. O projeto está dividido em `backend` (API em Flask,
com autenticação JWT) e `frontend_flutter` (app mobile em Flutter), implementando os
20 requisitos funcionais (RF01–RF20) do relatório de elicitação de requisitos.

**Novo no projeto?** Comece pelo [guia do código](docs/GUIA_DO_CODIGO.md): ele mostra por
onde ler, como as peças se ligam e onde está cada regra de negócio.

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
    ├── controllers/                → uma classe por recurso (UsuarioController, MovimentacaoController, ...)
    ├── models/                     → entidades e CRUD básico (salvar/atualizar/deletar/listar_todos/buscar_por_id)
    ├── repositories/                → consultas específicas que vão além do CRUD básico
    ├── services/                   → uma classe por funcionalidade, agrupadas por Model
    │   ├── usuario/                → CriarUsuarioService, AutenticarUsuarioService, ...
    │   ├── movimentacao/           → CriarMovimentacaoService, CalcularSaldoService, ...
    │   ├── meta/                   → CriarMetaService, CalcularStatusReservaEmergenciaService, ...
    │   ├── investimento/           → CriarInvestimentoService, ListarRankingInvestimentosService, ...
    │   ├── limite_categoria/       → DefinirLimiteCategoriaService, ...
    │   ├── recorrencia/            → CriarRecorrenciaService, LancarRecorrenciasPendentesService, ...
    │   ├── importacao/             → LerExtratoOfxService, AnalisarExtratoService, ConfirmarImportacaoService
    │   └── mercado/                → BuscarCotacaoDolarService, BuscarTaxasMercadoService, BuscarTitulosTesouroService
    └── database/
        └── create_database.sql     → script de criação do banco e tabelas
```

## Arquitetura

O backend segue quatro camadas:

- **Controllers** — uma classe por recurso (`UsuarioController`, `MovimentacaoController`,
  `MetaController`, `InvestimentoController`, `LimiteCategoriaController`,
  `OrientacaoController`, `MercadoController`). Cada método da classe recebe a
  requisição HTTP, interpreta os dados, chama a Service correspondente e devolve a
  resposta — nenhuma regra de negócio fica na Controller. As instâncias são registradas
  nas rotas do Blueprint via `add_url_rule(..., view_func=controller.metodo, ...)`. As
  rotas de dados financeiros exigem um token JWT (`Authorization: Bearer <token>`) e
  operam sempre sobre o usuário autenticado, nunca sobre um `usuario_id` informado
  pelo cliente.
- **Services** — cada funcionalidade/caso de uso é uma classe própria, em um arquivo
  próprio (ex.: `CriarMovimentacaoService`, `CalcularSaldoService`), agrupadas em
  pastas por Model (`services/usuario/`, `services/movimentacao/`, ...). Toda Service
  expõe um método de instância `executar(...)`, que valida os dados e coordena o caso
  de uso chamando a Model (CRUD básico) ou o Repository (consultas avançadas), já
  devolvendo o resultado pronto para virar JSON — a Controller só chama
  `MinhaService().executar(...)` e faz `jsonify(...)`. Erros de validação são
  `ValueError` (a Controller devolve 400); `services/erros.py` traz o
  `ErroAutenticacao` usado no login (401).
- **Models** — representam as entidades do domínio, herdando de `ModeloBase`
  (Flask-SQLAlchemy), que fornece `salvar()`, `deletar()`, `listar_todos()` e
  `buscar_por_id(id)`. Cada Model concreta implementa seu próprio `atualizar(...)`,
  já que os campos aceitos variam por entidade (ex.: `Usuario.atualizar(nome=,
  email=, perfil_risco=, renda_mensal=)`).
- **Repositories** — concentram consultas específicas que vão além do CRUD: filtros
  (`WHERE`), agregações (`SUM`/`GROUP BY`), ordenações (`ORDER BY`) e junções (`JOIN`).
  Todo acesso a dados é feito com **SQL puro**, via `db.session.execute(text(...))` —
  nunca com o ORM (`.query()`/`.filter()`) nem chamando métodos da Model. Não existem
  Repositories só para repetir CRUD simples.

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
- **Recorrencia** — descricao, tipo, valor, categoria, dia_mes, data_inicio, ativa,
  ultimo_mes_lancado. Receita ou despesa que o sistema lança sozinho todo mês. FK para Usuario.
- **ScoreHistorico** — data, score. Um retrato do score financeiro por dia, base do
  gráfico de evolução. FK para Usuario.

- **TransacaoImportada** — identificador. Marca cada linha de extrato bancário que já
  virou movimentação, para a mesma transação não ser importada duas vezes. FK para Usuario.

`Recorrencia`, `ScoreHistorico` e `TransacaoImportada` são extensões posteriores ao
relatório de elicitação: não fazem parte das 7 entidades do DER original nem dos RF01–RF20.

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
| GET | `/api/movimentacoes/relatorio-mensal/exportar` | Relatório mensal como arquivo — `formato=pdf\|csv`, `ano`, `mes` |
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
| GET | `/api/orientacao/score/historico` | Evolução do score — um ponto por dia consultado (`dias`, padrão 90) |

### Recorrências

| Método | Rota | Ação |
|--------|------|------|
| GET / POST | `/api/recorrencias` | Listar / cadastrar receita ou despesa que se repete todo mês |
| PUT / DELETE | `/api/recorrencias/<id>` | Editar, pausar (`ativa=false`) ou retomar / excluir |

### Importação de extrato bancário

| Método | Rota | Ação |
|--------|------|------|
| POST | `/api/importacao/analisar` | Lê um extrato OFX (`arquivo_base64`) e devolve as transações para revisão. Não grava nada |
| POST | `/api/importacao/confirmar` | Grava como movimentações as transações escolhidas na revisão |

Cada transação analisada volta com uma `situacao`: `nova`, `ja_importada` (veio em
importação anterior), `possivel_duplicata` (há movimentação de mesmo valor em data
próxima, digitada ou lançada por recorrência) ou `movimentacao_interna` (aplicação,
resgate, fatura). Só as `nova` vêm marcadas; a decisão final é do usuário. O app não se
conecta ao banco: o usuário exporta o arquivo e o envia.

Não há agendador: as recorrências vencidas são lançadas quando o usuário faz qualquer
chamada autenticada (`token_obrigatorio` → `LancarRecorrenciasPendentesService`),
cobrindo também os meses em que o app ficou fechado. A coluna `ultimo_mes_lancado` é
atualizada com checagem no próprio `UPDATE`, o que impede lançamento em dobro quando
várias requisições chegam juntas.

### Assistente de IA

| Método | Rota | Ação |
|--------|------|------|
| POST | `/api/ia/perguntar` | Envia a pergunta do usuário ao agente de IA e devolve a resposta |

A inteligência em si roda fora do Flask, num agente construído no **n8n**, que o
backend consulta via webhook — o mesmo padrão já usado para as APIs externas de
mercado. Junto da pergunta vai um retrato financeiro do usuário (saldo,
capacidade de economia, gastos por categoria, reserva de emergência, perfil de
risco e score), para que a resposta seja personalizada em vez de genérica, e
para que a IA respeite a regra de RF14/RF15 (só sugerir investimento depois da
reserva formada).

Configuração (variáveis de ambiente do backend):

| Variável | Obrigatória | Descrição |
|---|---|---|
| `N8N_WEBHOOK_URL` | sim | URL de produção do webhook do workflow no n8n |
| `N8N_API_KEY` | não | Enviada no header `X-API-Key`, se o webhook exigir autenticação |

Sem `N8N_WEBHOOK_URL` definida, a rota responde `503` com uma mensagem clara e o
app mostra o aviso no chat — nada quebra.

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

## Funcionalidades Implementadas

Cada item abaixo está disponível de ponta a ponta: **Tela (Flutter) → API Flask →
Controller (classe) → Service (`executar()`) → Model/Repository → Banco de dados**.

1. Cadastrar usuário — `UsuarioController.criar` → `CriarUsuarioService`
2. Fazer login — `UsuarioController.login` → `AutenticarUsuarioService`
3. Fazer logout — `UsuarioController.logout` → `LogoutUsuarioService`
4. Registrar receita — `MovimentacaoController.criar` → `CriarMovimentacaoService`
5. Registrar despesa — `MovimentacaoController.criar` → `CriarMovimentacaoService`
6. Consultar saldo disponível em tempo real — `MovimentacaoController.saldo` → `CalcularSaldoService`
7. Criar meta financeira — `MetaController.criar` → `CriarMetaService`
8. Adicionar aporte a uma meta (com progresso recalculado) — `MetaController.atualizar` → `AtualizarMetaService`
9. Consultar histórico de transações com filtro por período e categoria — `MovimentacaoController.listar` → `ListarMovimentacoesService`
10. Consultar gastos por categoria (gráfico) — `MovimentacaoController.gastos_por_categoria` → `CalcularGastosPorCategoriaService`
11. Definir limite de gasto por categoria — `LimiteCategoriaController.definir` → `DefinirLimiteCategoriaService`
12. Consultar alertas de inatividade e de limite excedido — `MovimentacaoController.alertas` → `GerarAlertasService`
13. Consultar status da reserva de emergência — `MetaController.reserva_emergencia` → `CalcularStatusReservaEmergenciaService`
14. Consultar guia financeiro passo a passo — `OrientacaoController.guia` → `GerarGuiaFinanceiroService`
15. Consultar score financeiro (0–1000) — `OrientacaoController.score` → `CalcularScoreFinanceiroService`
16. Atualizar perfil de investidor — `UsuarioController.atualizar` → `AtualizarUsuarioService`
17. Cadastrar investimento na carteira — `InvestimentoController.criar` → `CriarInvestimentoService`
18. Consultar cotação do dólar com histórico (integração externa — AwesomeAPI) — `MercadoController.dolar` → `BuscarCotacaoDolarService`
19. Consultar taxas oficiais Selic/CDI/IPCA (integração externa — Banco Central) — `MercadoController.taxas` → `BuscarTaxasMercadoService`
20. Consultar títulos do Tesouro Direto ofertados agora (integração externa — Tesouro Transparente) — `MercadoController.tesouro` → `BuscarTitulosTesouroService`
21. Conversar com o assistente de IA sobre a própria situação financeira (integração externa — agente no n8n) — `IaController.perguntar` → `ConsultarIaService`
22. Cadastrar receita/despesa recorrente, lançada automaticamente todo mês — `RecorrenciaController.criar` → `CriarRecorrenciaService` / `LancarRecorrenciasPendentesService`
23. Exportar o relatório mensal em PDF ou CSV — `MovimentacaoController.exportar_relatorio` → `ExportarRelatorioMensalService`
24. Acompanhar a evolução do score financeiro — `OrientacaoController.historico_score` → `ListarHistoricoScoreService`
25. Importar extrato bancário (OFX) com revisão antes de gravar — `ImportacaoController.analisar` / `confirmar` → `AnalisarExtratoService` / `ConfirmarImportacaoService`

## Funcionalidades (telas do app Flutter)

- **Início** — saldo em tempo real, economia do mês, tempo de sobrevivência, prévia
  das metas e o guia financeiro em destaque.
- **Metas** — criação e acompanhamento de metas com barra de progresso, reserva de
  emergência com aporte dedicado, e aporte mensal sugerido por meta.
- **Relatório** — gráfico de gastos por categoria, notificações de comportamento
  financeiro e histórico completo de transações com filtros. No topo, atalhos para as
  importação de extrato do banco, as recorrências e a exportação do mês em PDF/CSV; ao
  registrar uma transação, a opção "Repetir todo mês" já a cadastra como recorrente.
- **Investir** — score financeiro com gráfico de evolução, carteira de investimentos e
  sugestões personalizadas por perfil de risco, liberadas após a reserva de emergência.
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

O app procura o backend em `localhost:5000`. Para apontar para outro endereço sem editar
o código, passe `--dart-define=API_URL=http://ENDERECO:5000` no `flutter run`/`flutter build`.

### 3. Conta de demonstração

Para apresentar o app sem digitar dezenas de transações antes:

```bash
cd backend
python criar_conta_demo.py
```

Cria a conta `demo@investai.com` (senha `demo1234`) com três meses de movimentações,
recorrências, metas, reserva de emergência pela metade, um limite estourado e histórico
de score. Todos os dados são fictícios — inclusive os pontos antigos do score, que o
sistema não tem como calcular para trás. Rodar de novo recria só essa conta, com as
datas atualizadas; as demais não são tocadas.

Para experimentar a importação sem usar o extrato de ninguém, `python
gerar_extrato_exemplo.py` grava um extrato fictício do mês passado em
`backend/instance/extrato_exemplo.ofx`. Importado na conta de demonstração, ele mostra o
app apontando o salário, o aluguel, a internet e o streaming que já estavam lançados.
A importação funciona na versão web do app (navegador do PC ou do celular).

### 4. Testar pelo navegador do celular

Com o celular na mesma rede Wi-Fi do computador (PowerShell):

```powershell
# Terminal 1 - backend aceitando conexões da rede (o modo debug é desligado sozinho)
cd backend
$env:INVESTAI_HOST = "0.0.0.0"; python app.py

# Terminal 2 - app compilado e servido para a rede
cd frontend_flutter
flutter build web
python -m http.server 8080 --bind 0.0.0.0 --directory build/web
```

Descubra o IP do computador com `ipconfig` (linha "Endereço IPv4") e abra
`http://ESSE_IP:8080` no navegador do celular. Na web o app usa o endereço da própria
página para achar o backend, então não é preciso configurar mais nada. Na primeira vez o
Windows pergunta se o Python pode receber conexões: permita em redes privadas.

### 5. Testes

```bash
cd backend && python -m unittest          # regras de negócio e rotas
cd frontend_flutter && flutter test       # modelos, sessão e telas
```

Os testes de tela do Flutter (`test/telas_test.dart`) montam as abas com as respostas
reais da API para a conta de demonstração, gravadas em `test/apoio/respostas_api.json`.
Ao mudar o que uma rota devolve, regrave o arquivo com
`python -m tests.gerar_respostas_para_flutter` (na pasta `backend`).

## Tecnologias

**Backend:** Python, Flask, Flask-SQLAlchemy, Flask-Cors, PyJWT, Werkzeug (hash de
senha), fpdf2 (relatório em PDF) e SQLite (o SQL de produção é voltado a MySQL/MariaDB).

**Frontend:** Flutter/Dart, `http` (cliente da API), `shared_preferences` (sessão
local), `google_fonts`, `fl_chart` (gráficos), `path_provider` e `web` (salvar o
relatório exportado).
