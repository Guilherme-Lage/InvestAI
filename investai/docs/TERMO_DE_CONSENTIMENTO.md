# TERMO DE CONSENTIMENTO PARA TRATAMENTO DE DADOS PESSOAIS — InvestAI

**Versão 1.1**

Este Termo de Consentimento formaliza sua autorização expressa, livre, informada e
inequívoca para o tratamento de seus dados pessoais pelo Projeto **InvestAI**, em
conformidade com a Lei nº 13.709/2018 — Lei Geral de Proteção de Dados (LGPD), bem como
com os princípios e diretrizes das normas ISO/IEC 27001, ISO/IEC 27701 e ISO/IEC 29100,
que estabelecem boas práticas de segurança da informação, privacidade e proteção de
dados pessoais.

O consentimento do titular é uma das bases legais para o tratamento de dados pessoais,
conforme o art. 7º, I, da LGPD, devendo ser registrado e mantido como evidência pelo
Projeto InvestAI.

Ao utilizar o sistema, o titular declara ter lido, compreendido e consentido
expressamente com o tratamento de seus dados pessoais, nos termos a seguir.

---

## CLÁUSULA PRIMEIRA — DO OBJETO DO CONSENTIMENTO E DOS DADOS TRATADOS

O titular AUTORIZA o Projeto InvestAI a tratar os seguintes dados pessoais, cada um
vinculado à finalidade que o justifica:

| Dado pessoal | Finalidade |
|---|---|
| Nome | Identificar o titular na interface e personalizar as orientações |
| E-mail | Identificador único de acesso à conta (login) |
| Senha | Autenticação. **Armazenada exclusivamente como hash** (algoritmo `scrypt`, biblioteca Werkzeug); a senha em texto não é gravada e não pode ser recuperada pelo projeto |
| Renda mensal declarada | Calcular capacidade de economia (RF08) e dimensionar as orientações |
| Despesas estimadas no cadastro (total e parcela fixa) | Calcular a meta de reserva de emergência antes de existir histórico (RF14/RF15) e orientar o guia financeiro (RF16) |
| Receitas e despesas registradas (valor, data, descrição, categoria) | Saldo em tempo real (RF05), relatório mensal (RF10), gráfico por categoria (RF11), alertas (RF12/RF13) e histórico (RF19) |
| Metas financeiras (título, valor-alvo, valor atual, prazo) | Acompanhamento de progresso (RF06/RF07) e cálculo da reserva de emergência |
| Investimentos cadastrados (nome, tipo, valor aplicado, indexador, data de aplicação) | Acompanhar a carteira e calcular rendimento com base em taxas públicas |
| Limites de gasto por categoria | Emitir alertas quando o limite é ultrapassado (RF13) |
| Receitas e despesas recorrentes (descrição, valor, categoria, dia do mês) | Lançar automaticamente, todo mês, as contas que se repetem |
| Transações de extrato bancário importado pelo titular (data, descrição, valor) e o código de cada uma no banco | Registrar receitas e despesas sem digitação (RF03/RF04) e impedir que a mesma transação seja importada duas vezes |
| Histórico do score financeiro (data e pontuação) | Mostrar a evolução do score ao longo do tempo (RF20) |
| Perfil de investidor declarado (conservador, moderado ou arrojado) | Personalizar as sugestões de investimento (RF18) |
| Registro deste consentimento (aceite, versão e data/hora) | Comprovar o consentimento, conforme art. 7º, I, da LGPD |
| Identificador de sessão (JWT) e registro de sessões encerradas | Manter o acesso autenticado e invalidar sessões após logout (RF02) |

**Extrato bancário:** a importação é opcional e parte sempre do titular, que exporta o
arquivo no próprio banco e o envia ao aplicativo. O InvestAI **não se conecta ao banco**
nem solicita senha, token ou qualquer credencial bancária. O arquivo é lido para extrair
as transações e **não é armazenado**; ficam gravadas apenas as transações que o titular
confirmar após revisá-las, além do código que as identifica no extrato. Os números do
banco e da conta presentes no arquivo ficam gravados apenas como parte desse código, para
distinguir transações de contas diferentes.

**Dados sensíveis:** o InvestAI **não solicita** dados sensíveis na acepção do art. 5º,
II, da LGPD (origem racial, convicção religiosa, opinião política, dado de saúde, dado
biométrico, entre outros). Contudo, os campos de descrição de receitas e despesas são de
preenchimento livre pelo titular, de modo que informações sensíveis podem ser inseridas
por iniciativa dele (por exemplo, ao descrever uma despesa médica). O titular é orientado
a não registrar informações sensíveis nesses campos. Caso o faça, tais dados recebem o
mesmo tratamento de confidencialidade descrito na Cláusula Quinta.

---

## CLÁUSULA SEGUNDA — DAS FINALIDADES DO TRATAMENTO

Os dados pessoais serão utilizados exclusivamente para:

1. Calcular e exibir indicadores financeiros do próprio titular: saldo, capacidade de
   economia, tempo de sobrevivência sem renda, relatórios, gráficos por categoria e
   score financeiro.
2. Gerar orientações educativas personalizadas, incluindo a meta de reserva de
   emergência e sugestões de investimento compatíveis com o perfil declarado.
3. Permitir o diálogo com o assistente de inteligência artificial do aplicativo, nos
   termos e limites da Cláusula Terceira.
4. Autenticar o acesso à conta e encerrar sessões com segurança.

**Base legal:** o tratamento tem como fundamento o consentimento livre, informado e
inequívoco do titular (art. 7º, I, da LGPD), manifestado no ato do cadastro e registrado
pelo sistema com data, hora e versão deste Termo.

O InvestAI **não utiliza** os dados para publicidade, formação de perfil para fins
comerciais, venda ou cessão onerosa a terceiros.

---

## CLÁUSULA TERCEIRA — DO COMPARTILHAMENTO DE DADOS COM SERVIÇO DE INTELIGÊNCIA ARTIFICIAL

Esta cláusula descreve o único compartilhamento de dados pessoais realizado pelo sistema,
e exige atenção do titular.

Ao utilizar a funcionalidade de **assistente de inteligência artificial**, e somente
nesse momento, o InvestAI transmite a um serviço de IA externo, além da pergunta
digitada pelo titular, um resumo da sua situação financeira, composto por:

- nome;
- perfil de investidor declarado;
- renda mensal declarada;
- saldo atual;
- capacidade de economia mensal;
- total de gastos agrupados por categoria;
- despesa média mensal;
- situação da reserva de emergência (valor guardado, valor ideal, título e prazo da meta de
  reserva e se está completa);
- score financeiro e a pontuação de cada critério que o compõe;
- um identificador numérico interno da conta, usado para manter o histórico da conversa.

**Não são transmitidos:** e-mail, senha (nem seu hash), descrições individuais de
receitas e despesas, nem qualquer documento.

O envio é necessário porque, sem esses dados, o assistente responderia de forma genérica,
o que inviabilizaria a finalidade educativa personalizada do projeto.

O processamento é realizado por meio de um fluxo de automação (n8n) que encaminha a
requisição ao provedor de modelo de linguagem contratado pelo projeto
**Google — Gemini API**, podendo
envolver **transferência internacional de dados** (art. 33 da LGPD), uma vez que a
infraestrutura do provedor pode estar localizada fora do território nacional. O titular
declara ciência dessa circunstância.

**O uso do assistente é opcional.** O titular pode utilizar todas as demais
funcionalidades do InvestAI sem acionar o assistente, caso em que nenhum dado é enviado
a terceiros.

Fora dessa hipótese, os dados **não são compartilhados** com terceiros, ressalvado o
cumprimento de obrigação legal ou ordem de autoridade competente.

---

## CLÁUSULA QUARTA — DA IDENTIFICAÇÃO DO CONTROLADOR E DO ENCARREGADO (DPO)

**Controlador:** Projeto Acadêmico InvestAI, desenvolvido no âmbito do Curso Técnico em
Informática — disciplina Projeto de Software, **Colégio COTEMIG**.

**Encarregado pelo Tratamento de Dados Pessoais (DPO):** indicado na Cláusula Oitava,
conforme exigido pelo art. 41 da LGPD.

---

## CLÁUSULA QUINTA — DAS MEDIDAS DE SEGURANÇA E DAS LIMITAÇÕES DO PROJETO

O tratamento observa os princípios da LGPD e busca alinhamento com as boas práticas de
governança em privacidade das normas ISO/IEC 27001, ISO/IEC 27701 e ISO/IEC 29100.

**Medidas efetivamente implementadas no sistema:**

- Armazenamento da senha exclusivamente como hash criptográfico, sem possibilidade de
  reversão pelo projeto;
- Exigência de senha com no mínimo 6 caracteres, contendo letra, número e caractere
  especial;
- Autenticação por token de sessão (JWT) com prazo de expiração;
- Invalidação de sessão no logout, por meio de lista de tokens revogados, impedindo o
  reuso do token após a saída;
- Controle de acesso por titular: toda requisição a dados financeiros exige sessão válida,
  e o sistema verifica se o registro solicitado pertence ao titular autenticado, negando
  acesso a dados de outras contas;
- Exclusão em cascata: ao excluir a conta, são apagados também todos os dados vinculados a
  ela — movimentações, metas, investimentos, limites de categoria, recorrências,
  transações importadas de extrato, histórico do score e registro de sessões encerradas.
  A exclusão pode ser feita pelo próprio titular no aplicativo, mediante confirmação da
  senha.

**Limitações conhecidas, declaradas por transparência:**

Por se tratar de **projeto acadêmico executado em ambiente de desenvolvimento**, e não de
sistema em produção, o InvestAI **não possui**, nesta versão:

- comunicação cifrada por TLS/HTTPS entre aplicativo e servidor — a execução ocorre em
  rede local, em HTTP;
- criptografia do banco de dados em repouso — os dados são gravados em arquivo SQLite
  sem cifragem;
- monitoramento contínuo de logs de segurança, anonimização automática ou plano formal
  documentado de resposta a incidentes.

O titular declara estar ciente de que, nesta versão, o sistema **não deve ser utilizado
com dados financeiros reais e sensíveis**, sendo recomendado o uso de dados fictícios ou
aproximados para fins de demonstração e avaliação acadêmica.

---

## CLÁUSULA SEXTA — DOS DIREITOS DO TITULAR

O titular poderá, a qualquer momento:

- **Revogar o consentimento** (art. 8º, § 5º, da LGPD);
- **Solicitar a exclusão** de seus dados pessoais — disponível diretamente no aplicativo,
  pela opção "Excluir conta", na aba Perfil, com confirmação da senha;
- **Acessar, corrigir ou atualizar** seus dados — as informações de perfil, movimentações,
  metas e investimentos podem ser editadas ou removidas pelo próprio titular no aplicativo;
- Confirmar a existência de tratamento e obter acesso aos dados (art. 18, I e II);
- Solicitar a correção de dados incompletos, inexatos ou desatualizados (art. 18, III);
- Solicitar a anonimização, o bloqueio ou a eliminação de dados desnecessários ou
  tratados em desconformidade com a LGPD (art. 18, IV);
- Requerer a portabilidade dos dados, quando aplicável (art. 18, V);
- Obter informação sobre as entidades com as quais houve compartilhamento — atualmente
  restritas ao serviço de IA descrito na Cláusula Terceira (art. 18, VII);
- Ser informado sobre a possibilidade de não fornecer consentimento e sobre as
  consequências da negativa (art. 18, VIII);
- Peticionar à Autoridade Nacional de Proteção de Dados (ANPD) quando insatisfeito com a
  resposta do controlador (art. 18, § 1º).

**Consequência da negativa:** o consentimento é condição para a criação da conta, pois
todas as funcionalidades do InvestAI dependem do tratamento dos dados financeiros
informados. Sem o aceite, não é possível criar conta nem utilizar o sistema. O titular
que não desejar o envio de dados ao assistente de IA pode criar a conta e **simplesmente
não utilizar essa funcionalidade**, mantendo acesso a todas as demais.

---

## CLÁUSULA SÉTIMA — CANAL DE COMUNICAÇÃO

Canal oficial para dúvidas, solicitações e exercício dos direitos do titular:

**Guilherme Costa Lage Oliveira** — guilhermelagec762@gmail.com

As solicitações serão respondidas em prazo não superior a 15 (quinze) dias, contados da
data do requerimento, conforme art. 18, § 3º, da LGPD. Caso a resposta não seja
satisfatória, o titular poderá peticionar diretamente à Autoridade Nacional de Proteção
de Dados — ANPD (art. 18, § 1º).

---

## CLÁUSULA OITAVA — DA IDENTIFICAÇÃO DO ENCARREGADO (DPO)

O Projeto InvestAI indica como Encarregado de Proteção de Dados (DPO):

- **Nome:** Guilherme Costa Lage Oliveira
- **Cargo/Função:** Integrante do grupo — Encarregado de Proteção de Dados do Projeto InvestAI
- **Documento:** matrícula 12400505 — Colégio COTEMIG
- **E-mail para contato:** guilhermelagec762@gmail.com

---

## CLÁUSULA NONA — DO CONSENTIMENTO LIVRE, INFORMADO E INEQUÍVOCO

O titular confirma que o consentimento foi concedido de forma livre, sem coação, após
leitura e compreensão integral deste Termo.

O aceite é registrado pelo sistema no momento do cadastro, com **data, hora e versão do
Termo aceita**, constituindo a evidência exigida pelo art. 7º, I, da LGPD.

A revogação do consentimento não afeta a licitude do tratamento realizado no período
anterior à revogação (art. 8º, § 5º, da LGPD). Sendo o consentimento a única base legal
que fundamenta o tratamento no InvestAI, sua revogação implica a eliminação dos dados
pessoais correspondentes, o que é realizado pela exclusão da conta no aplicativo.

---

## CLÁUSULA DÉCIMA — DO TRATAMENTO DE DADOS DE CRIANÇAS E ADOLESCENTES

O InvestAI **destina-se a pessoas maiores de 18 anos** e não é direcionado a crianças ou
adolescentes.

Declara-se, por transparência, que **esta versão do sistema não realiza verificação
automatizada de idade** no cadastro. Caso se constate que uma conta foi criada por menor
de 18 anos sem o consentimento específico e em destaque de pelo menos um dos pais ou
responsável legal, nos termos do art. 14, § 1º, da LGPD, o projeto compromete-se a
excluir a conta e os dados associados mediante solicitação pelo canal da Cláusula Sétima.

Eventual evolução do projeto que venha a admitir titulares menores de 18 anos deverá
implementar, previamente, mecanismo de verificação de idade e de coleta do consentimento
do responsável legal.

---

## REGISTRO DO ACEITE

O aceite deste Termo é condição para a criação da conta e fica registrado no banco de
dados do sistema, na tabela `usuario`, por meio dos campos:

- `consentimento_aceito` — confirmação do aceite;
- `consentimento_versao` — versão do Termo vigente no momento do aceite;
- `consentimento_em` — data e hora do aceite.
