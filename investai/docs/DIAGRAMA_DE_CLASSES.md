# Diagrama de classes do domínio

Classes das Models do backend (`backend/models/`) e seus relacionamentos. O GitHub
desenha o diagrama abaixo automaticamente; a mesma figura está em
[diagrama_de_classes.png](diagrama_de_classes.png).

```mermaid
classDiagram
    direction LR

    class ModeloBase {
        <<abstract>>
        +int id
        +datetime data_criacao
        +datetime data_atualizacao
        +salvar()
        +deletar()
        +listar_todos()$
        +buscar_por_id(id)$
    }

    class Usuario {
        +str nome
        +str email
        +str senha_hash
        +str perfil_risco
        +float renda_mensal
        +float despesa_mensal_estimada
        +float despesa_fixa_estimada
        +bool consentimento_aceito
        +str consentimento_versao
        +datetime consentimento_em
        +definir_senha(senha)
        +verificar_senha(senha) bool
        +atualizar(...)
        +to_dict() dict
    }

    class Movimentacao {
        +str descricao
        +str tipo
        +float valor
        +str data
        +str categoria
        +int usuario_id
        +atualizar(...)
        +to_dict() dict
    }

    class Meta {
        +str titulo
        +float valor_alvo
        +float valor_atual
        +str prazo
        +str tipo
        +int usuario_id
        +progresso() float
        +atualizar(...)
        +to_dict() dict
    }

    class Investimento {
        +str nome
        +str tipo
        +float valor_aplicado
        +float rendimento_atual
        +str liquidez
        +str indexador
        +float percentual_indexador
        +date data_aplicacao
        +int usuario_id
        +atualizar(...)
        +to_dict() dict
    }

    class LimiteCategoria {
        +str categoria
        +float valor_limite
        +int usuario_id
        +atualizar(valor_limite)
        +to_dict() dict
    }

    class Recorrencia {
        +str descricao
        +str tipo
        +float valor
        +str categoria
        +int dia_mes
        +str data_inicio
        +bool ativa
        +str ultimo_mes_lancado
        +int usuario_id
        +atualizar(...)
        +to_dict() dict
    }

    class ScoreHistorico {
        +str data
        +int score
        +int usuario_id
        +atualizar(score)
        +to_dict() dict
    }

    class TransacaoImportada {
        +str identificador
        +int movimentacao_id
        +int usuario_id
    }

    class TokenRevogado {
        +str jti
        +int usuario_id
    }

    ModeloBase <|-- Usuario
    ModeloBase <|-- Movimentacao
    ModeloBase <|-- Meta
    ModeloBase <|-- Investimento
    ModeloBase <|-- LimiteCategoria
    ModeloBase <|-- Recorrencia
    ModeloBase <|-- ScoreHistorico
    ModeloBase <|-- TransacaoImportada
    ModeloBase <|-- TokenRevogado

    Usuario "1" *-- "0..*" Movimentacao : movimentacoes
    Usuario "1" *-- "0..*" Meta : metas
    Usuario "1" *-- "0..*" Investimento : investimentos
    Usuario "1" *-- "0..*" LimiteCategoria : limites_categoria
    Usuario "1" *-- "0..*" Recorrencia : recorrencias
    Usuario "1" *-- "0..*" ScoreHistorico : historico_score
    Usuario "1" *-- "0..*" TransacaoImportada : transacoes_importadas
    Usuario "1" *-- "0..*" TokenRevogado : tokens_revogados
    TransacaoImportada "0..1" --> "0..1" Movimentacao : registra
```

## Como ler

- **Herança.** Todas as Models herdam de `ModeloBase`, uma classe abstrata
  (`__abstract__ = True`) que herda de `db.Model`. Ela traz os campos comuns (`id`,
  `data_criacao`, `data_atualizacao`) e o CRUD básico: `salvar()`, `deletar()`,
  `listar_todos()` e `buscar_por_id()`. Cada Model que pode ser alterada implementa
  seu próprio `atualizar(...)`, porque os campos aceitos mudam de uma entidade para
  outra. `TransacaoImportada` e `TokenRevogado` são registros que só são criados e
  apagados, por isso não têm `atualizar`.
- **Composição (losango cheio).** `Usuario` é dono de todas as outras entidades: elas
  só existem ligadas a um usuário (`usuario_id` obrigatório) e são apagadas junto com
  ele (`cascade="all, delete-orphan"` em `models/usuario.py`), como acontece em
  "Excluir conta".
- **Associação (seta).** `TransacaoImportada` aponta para a `Movimentacao` que nasceu
  daquela linha do extrato. Uma não é dona da outra: quando o usuário exclui a
  movimentação, a marcação é removida e a linha pode ser importada de novo
  (`TransacaoImportadaRepository.liberar_da_movimentacao`). O projeto não tem
  agregação.

## Regras representadas por atributos

| Classe | Atributo | Valores |
|---|---|---|
| `Usuario` | `perfil_risco` | `conservador`, `moderado`, `arrojado` (RF18) |
| `Movimentacao`, `Recorrencia` | `tipo` | `renda` ou `gasto` |
| `Meta` | `tipo` | `geral` ou `reserva_emergencia` (RF14/RF15) |
| `LimiteCategoria` | (`usuario_id`, `categoria`) | único por usuário |
| `ScoreHistorico` | (`usuario_id`, `data`) | um registro por dia |
| `TransacaoImportada` | (`usuario_id`, `identificador`) | evita importar a mesma linha duas vezes |

`Recorrencia`, `ScoreHistorico` e `TransacaoImportada` foram acrescentadas depois do
DER do relatório de elicitação.
