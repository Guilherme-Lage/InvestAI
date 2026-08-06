# Frontend — InvestAI

Interface web que consome a API do backend (Flask). Contém as telas de cadastrar,
listar, editar e excluir para cada entidade do sistema: Usuários, Movimentações,
Investimentos e Metas.

## Telas

- index.html — página inicial
- usuarios.html / usuario_form.html — CRUD de usuários + filtro por perfil de risco
- movimentacoes.html / movimentacao_form.html — CRUD de movimentações + extrato com filtros (tipo, período) e ordenação
- investimentos.html / investimento_form.html — CRUD de investimentos + ranking por rendimento
- metas.html / meta_form.html — CRUD de metas + filtro por status (em andamento / concluídas)
- relatorio.html — relatório financeiro consolidado do usuário + busca de usuários com estatísticas

## Como usar

1. Inicie o backend (veja o README da pasta backend). Ele deve ficar rodando em
   http://127.0.0.1:5000
2. Abra o arquivo index.html no navegador (duplo clique) ou sirva a pasta com um
   servidor simples:

   python -m http.server 5500

   e acesse http://127.0.0.1:5500

O endereço da API pode ser ajustado no arquivo js/api.js (constante API_URL).
