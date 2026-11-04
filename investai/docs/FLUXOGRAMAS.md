# Fluxogramas dos casos de uso

Dois casos de uso acompanhados pelas camadas do sistema, do toque na tela até o banco de
dados e de volta. O GitHub desenha os diagramas abaixo automaticamente; as mesmas
figuras, para usar nos slides, estão em
[fluxograma_consultar_saldo.png](fluxograma_consultar_saldo.png) e
[fluxograma_definir_limite.png](fluxograma_definir_limite.png).

| Fluxograma | Caso de uso | Tipo |
|---|---|---|
| [1](#1-consultar-o-saldo-rf05) | Consultar o saldo (RF05) | Recuperação de dados |
| [2](#2-definir-o-limite-de-uma-categoria-rf13) | Definir o limite de gasto de uma categoria (RF13) | Entrada de dados |

Antes de chegar à Controller, toda rota de dados passa pelo decorator
`@token_obrigatorio` ([auth_decorators.py](../backend/controllers/auth_decorators.py)).
Ele confere o token, busca o `usuario_id` dentro dele e consulta o
`TokenRevogadoRepository` para recusar tokens de quem já fez logout. Por isso a
verificação aparece nos dois fluxogramas.

---

## 1. Consultar o saldo (RF05)

O usuário abre a aba Início e o app mostra o saldo. O saldo não fica guardado: a cada
pedido, o Repository soma as rendas e os gastos com SQL e a Service subtrai.

```mermaid
flowchart TD
    subgraph APP["App Flutter"]
        A1(["Usuário abre a aba Início"])
        A2["DashboardTab._carregar()<br/>chama ApiService.saldo()"]
        A3["GET /api/movimentacoes/saldo<br/>com o token no cabeçalho"]
        A4["Converte a resposta em número<br/>e mostra o saldo na tela"]
        A5["ApiService limpa a sessão<br/>e volta para o login"]
    end

    subgraph CTRL["Controller"]
        C1{"@token_obrigatorio:<br/>token válido e<br/>não revogado?"}
        C2["MovimentacaoController.saldo()<br/>chama CalcularSaldoService<br/>com g.usuario_id"]
        C3["Responde 200<br/>com o saldo em JSON"]
        C4["Responde 401"]
    end

    subgraph SERV["Service"]
        S1["CalcularSaldoService.executar(usuario_id)"]
        S2["saldo = rendas - gastos"]
    end

    subgraph REPO["Repository"]
        R1["MovimentacaoRepository<br/>.somar_por_tipo(usuario_id, 'renda')"]
        R2["MovimentacaoRepository<br/>.somar_por_tipo(usuario_id, 'gasto')"]
    end

    subgraph BANCO["Model / Banco de dados"]
        B1[("Tabela movimentacao<br/>(Model Movimentacao)<br/>SELECT COALESCE(SUM(valor), 0)<br/>WHERE usuario_id AND tipo")]
    end

    A1 --> A2 --> A3 --> C1
    C1 -- "não" --> C4 --> A5
    C1 -- "sim" --> C2 --> S1
    S1 --> R1
    R1 <--> B1
    R1 -- "total das rendas" --> R2
    R2 <--> B1
    R2 -- "total dos gastos" --> S2
    S2 --> C3 --> A4
```

| Camada | Arquivo |
|---|---|
| App | `frontend_flutter/lib/screens/dashboard_tab.dart`, `lib/services/api_service.dart` |
| Controller | `backend/controllers/movimentacao_controller.py` (método `saldo`) |
| Service | `backend/services/movimentacao/calcular_saldo_service.py` |
| Repository | `backend/repositories/movimentacao_repository.py` (método `somar_por_tipo`) |
| Model | `backend/models/movimentacao.py` |

---

## 2. Definir o limite de uma categoria (RF13)

No Perfil, o usuário escolhe uma categoria e digita o limite mensal. Só pode existir um
limite por categoria: se já houver, ele é atualizado; se não, é criado. Quem descobre
qual dos dois é o Repository, e quem grava é a Model.

```mermaid
flowchart TD
    subgraph APP["App Flutter"]
        A1(["Usuário escolhe a categoria,<br/>digita o valor e toca em<br/>'Salvar limite' no Perfil"])
        A2{"Valor maior<br/>que zero?"}
        A3["Nada é enviado"]
        A4["ApiService.definirLimite()<br/>POST /api/limites<br/>com categoria e valor_limite"]
        A5["Fecha o formulário e<br/>mostra o limite na lista"]
        A6["Mostra a mensagem<br/>de erro na tela"]
        A7["ApiService limpa a sessão<br/>e volta para o login"]
    end

    subgraph CTRL["Controller"]
        C1{"@token_obrigatorio:<br/>token válido e<br/>não revogado?"}
        C2["LimiteCategoriaController.definir()<br/>lê o JSON e chama a Service<br/>com g.usuario_id"]
        C3["Responde 201<br/>com o limite em JSON"]
        C4["Captura o ValueError<br/>e responde 400 com a mensagem"]
        C5["Responde 401"]
    end

    subgraph SERV["Service"]
        S1{"DefinirLimiteCategoriaService<br/>.executar(): categoria<br/>informada?"}
        S2{"Valor é um número<br/>maior que zero?"}
        S3["Levanta ValueError"]
        S4{"Já existe limite<br/>para a categoria?"}
        S5["Devolve limite.to_dict()"]
    end

    subgraph REPO["Repository"]
        R1["LimiteCategoriaRepository<br/>.buscar_por_categoria(usuario_id, categoria)"]
    end

    subgraph BANCO["Model / Banco de dados"]
        M1["LimiteCategoria.buscar_por_id()<br/>e .atualizar(valor_limite)"]
        M2["LimiteCategoria(...).salvar()"]
        B1[("Tabela limite_categoria")]
    end

    A1 --> A2
    A2 -- "não" --> A3
    A2 -- "sim" --> A4 --> C1
    C1 -- "não" --> C5 --> A7
    C1 -- "sim" --> C2 --> S1
    S1 -- "não" --> S3
    S1 -- "sim" --> S2
    S2 -- "não" --> S3
    S2 -- "sim" --> R1
    R1 -- "SELECT ... WHERE usuario_id<br/>AND categoria LIMIT 1" --> B1
    B1 -- "linha encontrada ou nada" --> S4
    S4 -- "não: cria" --> M2
    S4 -- "sim: atualiza" --> M1
    M1 -- "UPDATE" --> B1
    M2 -- "INSERT" --> B1
    M1 --> S5
    M2 --> S5
    S5 --> C3 --> A5
    S3 --> C4 --> A6
```

| Camada | Arquivo |
|---|---|
| App | `frontend_flutter/lib/screens/perfil_tab.dart`, `lib/services/api_service.dart` |
| Controller | `backend/controllers/limite_categoria_controller.py` (método `definir`) |
| Service | `backend/services/limite_categoria/definir_limite_categoria_service.py` |
| Repository | `backend/repositories/limite_categoria_repository.py` (método `buscar_por_categoria`) |
| Model | `backend/models/limite_categoria.py` (`atualizar`) e `backend/models/base.py` (`salvar`) |

### O que mostrar com este fluxograma

- **A divisão de trabalho entre as camadas.** O Repository só consulta, com SQL. A
  Service decide entre criar e atualizar. A Model grava, pelo ORM.
- **O caminho do erro.** A Service levanta `ValueError`, a Controller transforma em
  resposta 400 e o app mostra a mensagem. É a mesma convenção do projeto inteiro.
