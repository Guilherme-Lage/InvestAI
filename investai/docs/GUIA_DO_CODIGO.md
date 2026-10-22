# Guia do código — InvestAI

Este guia é para quem do grupo não escreveu uma parte do código e precisa entendê-la a
ponto de explicar para o professor. Ele não repete o [README](../README.md) (que lista
todas as rotas e requisitos): mostra **por onde começar a ler, como as peças se ligam e
onde está cada regra importante**.

Tempo estimado: 20 minutos de leitura, mais 1 hora abrindo os arquivos indicados.

---

## 1. O projeto em um minuto

- **Dois programas.** O `backend/` é uma API em Python (Flask) que guarda os dados e faz
  todas as contas. O `frontend_flutter/` é o app, que só mostra telas e chama a API.
- **O app não calcula nada importante.** Saldo, score, reserva, alertas: tudo é
  calculado no backend. Se a pergunta for "como o app chega nesse número?", a resposta
  está sempre em um arquivo de `backend/services/`.
- **A regra central do produto:** as sugestões de investimento só aparecem depois que o
  usuário junta uma reserva de emergência de 3 vezes a sua despesa média mensal
  (RF14/RF15).

## 2. Como rodar

```bash
# Terminal 1 — API
cd backend
pip install -r requirements.txt
python app.py                      # sobe em http://localhost:5000

# Terminal 2 — app
cd frontend_flutter
flutter pub get
flutter run -d chrome
```

Para já entrar com dados prontos, rode `python criar_conta_demo.py` na pasta `backend`
e use `demo@investai.com` / `Demo@1234`. Celular, assistente de IA e testes estão
explicados no README.

## 3. O mapa do backend: quatro camadas

Toda funcionalidade passa pelas mesmas quatro pastas, sempre nesta ordem:

| Camada | Pasta | O que faz | O que **não** faz |
|---|---|---|---|
| Controller | `controllers/` | Recebe a requisição HTTP, chama uma Service, devolve JSON | Regra de negócio |
| Service | `services/` | **A regra.** Uma classe por caso de uso, com um método `executar()` | Falar HTTP |
| Repository | `repositories/` | Consultas SQL que vão além do básico (somas, filtros, agrupamentos) | Decidir qualquer coisa |
| Model | `models/` | Representa uma tabela; salva, busca por id, apaga | Consultas elaboradas |

Duas convenções que valem para o projeto inteiro:

- **Erro de validação é `ValueError`.** A Service levanta, a Controller transforma em
  resposta 400 com `{"erro": "mensagem"}`, e o app mostra essa mensagem ao usuário.
- **O `usuario_id` nunca vem do app.** Ele sai do token de login (ver seção 6). Assim
  ninguém consegue ler ou alterar dados de outra pessoa trocando um número na requisição.

## 4. Siga uma funcionalidade do começo ao fim

A melhor forma de entender a arquitetura é acompanhar um clique. Exemplo: **registrar
uma despesa e ver o saldo mudar** (RF04 e RF05). Abra os arquivos na ordem:

1. **Tela.** Em [report_tab.dart](../frontend_flutter/lib/screens/report_tab.dart), a
   classe `_FormularioMovimentacao` monta o formulário. O método `_salvar()` cria um
   objeto `Movimentacao` e chama `ApiService.criarMovimentacao(...)`.
2. **Chamada à API.** Em [api_service.dart](../frontend_flutter/lib/services/api_service.dart),
   `criarMovimentacao` faz um `POST /api/movimentacoes`. O método `_headers()` coloca o
   token de login em toda chamada; `_tratarResposta()` transforma erro do backend em
   `ApiException`.
3. **Controller.** Em [movimentacao_controller.py](../backend/controllers/movimentacao_controller.py),
   o método `criar` pega o JSON, acrescenta o `usuario_id` do token e chama a Service.
   No fim do arquivo, as linhas `add_url_rule` ligam cada endereço a um método.
4. **Service.** [criar_movimentacao_service.py](../backend/services/movimentacao/criar_movimentacao_service.py)
   monta a `Movimentacao` e chama `salvar()`.
5. **Model.** [movimentacao.py](../backend/models/movimentacao.py) descreve a tabela. O
   `salvar()` vem de [base.py](../backend/models/base.py), que todas as Models herdam.
6. **De volta à tela.** O app recarrega e pede `GET /api/movimentacoes/saldo`.
7. **O cálculo.** [calcular_saldo_service.py](../backend/services/movimentacao/calcular_saldo_service.py)
   tem três linhas: soma as rendas, soma os gastos e subtrai. As somas são SQL em
   [movimentacao_repository.py](../backend/repositories/movimentacao_repository.py),
   método `somar_por_tipo`.

Repare que **o saldo não fica guardado em lugar nenhum**: é recalculado a cada pedido a
partir das movimentações. Por isso ele está sempre certo, e é esse o sentido de "tempo
real" no RF05. O mesmo vale para score, reserva e alertas.

Todas as outras funcionalidades seguem esse desenho. Para achar qualquer uma, procure o
endereço da rota no README e siga Controller → Service.

## 5. Onde está cada regra de negócio

São as contas que a banca mais tende a perguntar. Cada uma está em um arquivo pequeno
dentro de `backend/services/`.

| Regra | Como funciona | Arquivo |
|---|---|---|
| Saldo (RF05) | Soma das rendas menos soma dos gastos | `movimentacao/calcular_saldo_service.py` |
| Capacidade de economia (RF08) | Rendas menos gastos **do mês atual** | `movimentacao/calcular_capacidade_economia_service.py` |
| Despesa média mensal | Gastos dos últimos 90 dias divididos por 3. Sem nenhum gasto registrado, usa a estimativa informada no cadastro | `movimentacao/calcular_despesa_media_service.py` |
| Sobrevivência sem renda (RF09) | Saldo dividido pela despesa média mensal | `movimentacao/calcular_sobrevivencia_service.py` |
| Reserva de emergência (RF14/RF15) | Meta ideal = 3 × despesa média. Investimentos liberados quando o valor guardado na meta do tipo `reserva_emergencia` alcança esse valor | `meta/calcular_status_reserva_emergencia_service.py` |
| Guia financeiro (RF16) | Três situações, nesta ordem: saldo negativo → construir reserva → pronto para investir | `usuario/gerar_guia_financeiro_service.py` |
| Aporte sugerido (RF17) | Quanto falta dividido pelos meses até o prazo, limitado ao que o usuário consegue economizar no mês | `meta/listar_metas_service.py` |
| Alertas (RF12/RF13) | Inatividade: 3 dias ou mais sem registrar gasto. Limite: gasto do mês na categoria maior que o limite definido | `movimentacao/gerar_alertas_service.py` |
| Score (RF20) | De 0 a 1000, quatro critérios de 250 pontos: saldo positivo, progresso da reserva, metas concluídas e controle de gastos (perde 80 por categoria estourada) | `usuario/calcular_score_financeiro_service.py` |
| Sugestões por perfil (RF18) | Lista fixa por perfil (conservador, moderado, arrojado), enriquecida com as taxas oficiais do dia | `usuario/gerar_guia_financeiro_service.py` |

## 6. Login e segurança

- **Senha.** Nunca é guardada. No cadastro vira um hash (`Usuario.definir_senha`, em
  [usuario.py](../backend/models/usuario.py)); no login compara-se o hash. Para ser
  aceita, precisa ter 6 caracteres ou mais, com letra, número e caractere especial
  (`problema_na_senha`, em `services/usuario/criar_usuario_service.py`). O app confere a
  mesma regra antes de enviar, em `lib/utils/validacao_senha.dart`.
- **Token.** O login devolve um token JWT válido por 8 horas
  ([auth_service.py](../backend/services/auth_service.py)). O app o guarda e envia em
  toda chamada.
- **Proteção das rotas.** O decorator `@token_obrigatorio`, em
  [auth_decorators.py](../backend/controllers/auth_decorators.py), confere o token antes
  de qualquer rota de dados e deixa o `usuario_id` disponível em `g.usuario_id`.
- **Logout de verdade.** Um JWT continuaria valendo até expirar. Por isso o logout grava
  o identificador do token na tabela `token_revogado`, e o decorator recusa tokens que
  estejam lá.
- **Excluir conta.** O Perfil tem "Excluir conta", que pede a senha de novo e apaga a
  conta com todos os dados dela
  ([excluir_propria_conta_service.py](../backend/services/usuario/excluir_propria_conta_service.py)).
  É o direito de eliminação da LGPD que o termo promete. Senha errada responde 400, e não
  401, porque no app 401 encerra a sessão.
- **Consentimento.** Sem aceitar o termo de uso dos dados não há cadastro. O texto está
  em [TERMO_DE_CONSENTIMENTO.md](TERMO_DE_CONSENTIMENTO.md) e o resumo mostrado no app em
  `services/usuario/termos_consentimento.py`.

## 7. O que existe além dos RF01–RF20

Cinco funcionalidades foram acrescentadas depois do relatório de requisitos. Na
apresentação, convém dizer que são extensões. Três delas criaram tabelas que **não estão
no DER original** de 7 entidades: `recorrencia`, `score_historico` e
`transacao_importada`.

### Recorrências (contas que se repetem todo mês)
- **O que é.** O usuário cadastra aluguel, assinatura ou salário uma vez; o sistema lança
  a movimentação sozinho todo mês.
- **Por quê.** A tabela de observação do relatório aponta que planilhas são abandonadas
  porque exigem "atualização manual constante".
- **Como funciona.** Não há um programa rodando à meia-noite. Toda vez que o usuário usa
  o app, o decorator `token_obrigatorio` chama
  [lancar_recorrencias_pendentes_service.py](../backend/services/recorrencia/lancar_recorrencias_pendentes_service.py),
  que lança o que venceu, inclusive de meses em que o app ficou fechado.
- **Detalhe que vale explicar.** A coluna `ultimo_mes_lancado` evita lançar duas vezes.
  Ela é atualizada com a condição dentro do próprio `UPDATE` (ver `marcar_mes_lancado`
  em `repositories/recorrencia_repository.py`), então duas requisições simultâneas não
  duplicam a conta.

### Exportação do relatório mensal (PDF e CSV)
- **Como funciona.** O backend monta o arquivo em
  [exportar_relatorio_mensal_service.py](../backend/services/movimentacao/exportar_relatorio_mensal_service.py)
  e o app só o salva. O CSV sai no formato que o Excel em português abre direto.

### Evolução do score
- **Como funciona.** O score é recalculado a cada consulta e não tem passado. Para
  desenhar o gráfico, grava-se um retrato por dia em `score_historico`, no momento em
  que o usuário abre a aba Investir
  ([listar_historico_score_service.py](../backend/services/usuario/listar_historico_score_service.py)).
- **Limitação.** O gráfico começa vazio para conta nova e só ganha linha a partir do
  segundo dia de uso.

### Importação de extrato bancário
- **O que é.** O usuário exporta o extrato no banco, em formato OFX, e envia ao app, em
  vez de digitar cada transação.
- **Por que não conectar direto ao banco.** Isso (Open Finance) exige ser instituição
  autorizada pelo Banco Central. Importar o arquivo é o caminho possível para o projeto,
  e o app nunca pede senha de banco.
- **Dois passos, de propósito.** `analisar` lê o arquivo e devolve as transações **sem
  gravar nada**; o usuário revisa; `confirmar` grava só as que ele deixou marcadas. Os
  três arquivos estão em `backend/services/importacao/` e têm a explicação no topo.
- **Como não duplica.** Cada transação do banco tem um código próprio. Os códigos já
  importados ficam em `transacao_importada`, ligados ao lançamento que geraram;
  importar o mesmo período de novo não cria nada repetido.
- **Como desfazer um erro.** Apagar um lançamento importado apaga também a marca dele,
  então a linha volta a aparecer como nova na próxima importação
  (`DeletarMovimentacaoService`). Isso só vale para o que foi importado depois dessa
  ligação existir: as marcas mais antigas não sabem a qual lançamento pertencem.
- **O que vem desmarcado na revisão.** Transação de mesmo valor em data próxima a algo
  já registrado (por exemplo, o aluguel que a recorrência lançou) e dinheiro que só
  mudou de lugar (aplicação, resgate, fatura). A decisão final é sempre do usuário.
- **Ajuste para bater com o saldo do banco.** O extrato só traz o que entrou e saiu no
  período: falta o dinheiro que já estava na conta antes. E o que o usuário deixa de fora
  (uma aplicação, uma transferência para outra conta dele) saiu da conta no banco, mas
  não sai no app. Quando o banco informa o saldo no arquivo (bloco `LEDGERBAL`), a tela
  de revisão mostra um lançamento de ajuste, na categoria "Ajuste de saldo", calculado
  como `saldo do banco - saldo do app até essa data - (entradas - saídas das linhas
  marcadas)`. O valor muda a cada linha marcada ou desmarcada. Na **primeira importação**
  de uma conta, o ajuste vem marcado e o saldo do app passa a ser exatamente o do banco.
  Se o ajuste ficou de fora (desmarcado, ou app antigo em cache), a conta continua "não
  igualada" e ele vem marcado de novo na próxima importação. Depois que um ajuste da
  conta foi gravado, uma diferença indica algo que não bate: o ajuste aparece desmarcado, como
  aviso, e a pessoa decide. O backend manda os números (`_ajuste_de_saldo`, em
  `analisar_extrato_service.py`) e a conta final é feita no app (`AjusteSaldo.valorPara`).
  Dinheiro aplicado deve ser registrado na aba Investir.
- **Categoria.** Sugerida por palavras-chave em
  [sugerir_categoria.py](../backend/services/importacao/sugerir_categoria.py)
  ("UBER" → transporte), ou pela categoria que o usuário já deu a uma transação de mesmo
  nome. Não usa IA; o usuário corrige na tela.
- **Limitações.** Só OFX, e só na versão web do app (navegador do PC ou do celular).

### Trilha "Aprenda a investir"
- **O que é.** Seis lições curtas, na aba Investir, que vão abrindo conforme a pessoa
  avança no guia: as três básicas (inflação, juros compostos, reserva) sempre; o primeiro
  investimento e risco/liquidez quando o saldo fica positivo; renda variável só com a
  reserva completa.
- **Por quê.** O app dizia o que fazer, mas não ensinava. A ideia é a pessoa aprender
  sobre cada passo antes de chegar nele. A lição central mostra que guardar a reserva no
  Tesouro Selic já é o primeiro investimento, com o passo a passo para comprar.
- **Onde mexer.** Todo o texto está em
  [licoes.dart](../frontend_flutter/lib/conteudo/licoes.dart), separado das telas: para
  revisar ou criar uma lição, basta copiar uma das existentes. Os termos do glossário
  viram links sozinhos, e cada lição pode ter um trecho "Com os seus números", calculado
  com as taxas do dia e a reserva da pessoa.
- **Progresso.** Fica guardado no aparelho, por conta
  ([progresso_licoes.dart](../frontend_flutter/lib/services/progresso_licoes.dart)). Não
  usa o backend nem o banco de dados.
- **Limitação.** O conteúdo é fixo no app e não há quiz para conferir o que foi
  aprendido.

### Assistente de IA
- **Como funciona.** O backend não tem um modelo de IA dentro dele. Ele envia a pergunta,
  junto com um resumo da situação financeira do usuário, para um agente montado no n8n,
  que usa o Gemini
  ([consultar_ia_service.py](../backend/services/ia/consultar_ia_service.py)).
- **Por que mandar o resumo.** Sem ele a resposta seria genérica, que foi a principal
  queixa da pesquisa com usuários. O resumo inclui se a pessoa já pode investir, para a
  IA respeitar a regra da reserva.
- **Se o n8n estiver fora do ar,** a rota responde com erro tratado e o chat mostra um
  aviso; o resto do app continua funcionando.

## 8. O app Flutter

- **Uma tela por arquivo**, em `lib/screens/`. As cinco abas são `dashboard_tab`
  (Início), `metas_tab`, `report_tab` (Relatório), `investimentos_tab` (Investir) e
  `perfil_tab`; quem alterna entre elas é `home_screen.dart`.
- **Toda tela segue o mesmo roteiro:** `initState` chama `_carregar()`, que busca os
  dados no `ApiService` e chama `setState`; o `build` mostra carregando, erro com botão
  "Tentar novamente", ou o conteúdo.
- **`ApiService` é a única porta para o backend.** Nenhuma tela faz chamada HTTP por
  conta própria.
- **`lib/models/`** tem as classes que convertem o JSON da API em objetos Dart
  (`fromJson`) e de volta (`toJson`).
- **Sessão expirada.** Se qualquer chamada responder 401, o `ApiService` limpa a sessão
  e leva o usuário para o login, de qualquer tela.

## 9. Testes

```bash
cd backend && python -m unittest        # regras de negócio e rotas
cd frontend_flutter && flutter test     # modelos, sessão e telas
```

- **Backend** (`backend/tests/`). Cada arquivo testa uma área. Os nomes dos testes são
  frases que descrevem o comportamento, por exemplo
  `test_nao_lanca_duas_vezes_no_mesmo_mes`. Ler só os nomes já mostra o que o sistema
  garante. Rodam com banco em memória e sem internet.
- **Flutter** (`frontend_flutter/test/`). `telas_test.dart` monta todas as abas em dois
  tamanhos de celular, com respostas reais do backend gravadas em
  `test/apoio/respostas_api.json`.
- **Se mudar o que uma rota devolve,** regrave esse arquivo com
  `python -m tests.gerar_respostas_para_flutter` (na pasta `backend`).

## 10. Receita para fazer uma mudança

Para acrescentar uma funcionalidade nova, copie o formato de uma que já existe. A menor
de todas é o limite por categoria (procure `limite_categoria` nas quatro pastas).

1. **Model**, se precisar de tabela nova: crie em `models/` e registre em
   `models/__init__.py`. A tabela é criada sozinha quando o backend sobe.
2. **Repository**, se precisar de consulta com SQL.
3. **Service** com o método `executar()`. É aqui que entra a regra.
4. **Controller**: um método com `@token_obrigatorio` e uma linha `add_url_rule`.
   Blueprint novo precisa ser registrado em `controllers/__init__.py` e em `app.py`.
5. **Teste** em `backend/tests/`.
6. **App**: um método no `ApiService` e a tela que o chama.

Um cuidado: criar tabela nova funciona sozinho, mas **acrescentar coluna a uma tabela
que já existe não**, porque o `db.create_all()` não altera tabelas antigas. Para isso,
registre a coluna também em `COLUNAS_ACRESCENTADAS`, em
[migracoes.py](../backend/models/migracoes.py): o backend a acrescenta ao subir, sem
perder os dados.

## 11. Limitações conhecidas

Vale saber de cor, porque é melhor apontar do que ser pego de surpresa.

- **RF12 fala em "notificação"** e o app mostra um alerta dentro da aba Relatório. Não
  há notificação enviada ao aparelho.
- **Recorrência lançada conta como despesa registrada**, então adia o alerta de
  inatividade nos dias seguintes ao lançamento.
- **O token expira em 8 horas** e não é renovado: depois disso o usuário faz login de
  novo.
- **O banco é SQLite**, um arquivo local, adequado a um projeto acadêmico. O script
  `database/create_database.sql` traz o equivalente para MySQL.
- **Não há limite de tentativas de login.**
- **O valor guardado nas metas é só um número informado pelo usuário**: aportar em uma
  meta não gera movimentação nem diminui o saldo.
- **Importação de extrato** só aceita OFX e só funciona na versão web.
- **As sugestões de investimento são educativas** e fixas por perfil. O app não executa
  investimentos nem tem parceria com banco ou corretora.
