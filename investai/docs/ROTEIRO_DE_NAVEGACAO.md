# Roteiro de navegação — "como esse número é calculado?"

Para ensaiar com o VS Code aberto. Em cada número: aponte na tela, abra os arquivos na
ordem (Ctrl+P e o nome do arquivo; F12 para pular de uma camada para a outra; Alt+←
para voltar) e fale o texto. Meta: menos de 1 minuto por número.

O caminho é sempre o mesmo:

```
Tela → ApiService → rota → Controller → Service → Repository → SQL
```

A Controller nunca calcula nada: só pega o usuário do token (`g.usuario_id`) e chama
a Service. Por isso dá para ir direto da Controller para a Service com F12.

---

## 1. Saldo — aba Início

| Camada | Abrir |
|---|---|
| Rota | `GET /api/movimentacoes/saldo` |
| Controller | `movimentacao_controller.py` → `saldo()` |
| Service | `calcular_saldo_service.py` |
| Repository | `movimentacao_repository.py` → `somar_por_tipo` |

**Falar:** "A Service pede ao Repository duas somas, das rendas e dos gastos, e
subtrai. O SQL é um `SUM(valor)` filtrando por usuário e tipo. O saldo não fica
guardado; é recalculado a cada pedido, por isso está sempre certo."

## 2. Capacidade de economia — aba Início

| Camada | Abrir |
|---|---|
| Rota | `GET /api/movimentacoes/capacidade-economia` |
| Controller | `movimentacao_controller.py` → `capacidade_economia()` |
| Service | `calcular_capacidade_economia_service.py` |
| Repository | `movimentacao_repository.py` → `resumo_mensal` |

**Falar:** "É o saldo só do mês atual. O Repository faz uma consulta só, com
`SUM(CASE WHEN tipo = 'renda' ...)` e `SUM(CASE WHEN tipo = 'gasto' ...)`, filtrando as
datas do mês. A Service subtrai saídas de entradas."

**Se perguntarem a diferença para o saldo:** o saldo é de todo o histórico; a
capacidade é só do mês.

## 3. Despesa média mensal — usada pela reserva e pela sobrevivência

| Camada | Abrir |
|---|---|
| Service | `calcular_despesa_media_service.py` |
| Repository | `movimentacao_repository.py` → `media_gastos_mensais` (que usa `somar_por_tipo`) |

**Falar:** "Soma os gastos dos últimos 90 dias e divide por 3. Se a pessoa ainda não
registrou nenhum gasto, usa a estimativa que ela informou no cadastro; senão a meta da
reserva nasceria zerada."

Não tem rota própria: é uma Service usada por outras Services. É um bom exemplo de
reaproveitamento.

## 4. Tempo de sobrevivência sem renda — aba Início

| Camada | Abrir |
|---|---|
| Rota | `GET /api/movimentacoes/sobrevivencia` |
| Controller | `movimentacao_controller.py` → `sobrevivencia()` |
| Service | `calcular_sobrevivencia_service.py` |
| Usa | `CalcularSaldoService` e `CalcularDespesaMediaService` (números 1 e 3) |

**Falar:** "Saldo dividido pela despesa média mensal: quantos meses a pessoa vive se
a renda parar. Se o saldo for negativo conta como zero. A Service não faz SQL; reaproveita
as duas Services que já existem."

## 5. Reserva de emergência e liberação dos investimentos — aba Metas

| Camada | Abrir |
|---|---|
| Rota | `GET /api/metas/reserva-emergencia` |
| Controller | `meta_controller.py` → `reserva_emergencia()` |
| Service | `calcular_status_reserva_emergencia_service.py` |
| Repository | `meta_repository.py` → `buscar_reserva_emergencia` |

**Falar:** "É a regra central do app. A meta ideal é 3 vezes a despesa média
(constante `MULTIPLICADOR_RESERVA_EMERGENCIA`). O Repository busca a meta do tipo
`reserva_emergencia` com SQL. Os investimentos são liberados quando o valor guardado
alcança a meta ideal: é a variável `liberado`."

## 6. Score de 0 a 1000 — tela Início (e aba Investir)

| Camada | Abrir |
|---|---|
| Rota | `GET /api/orientacao/score` |
| Controller | `orientacao_controller.py` → `score()` |
| Service | `calcular_score_financeiro_service.py` |
| Repository | `meta_repository.py` → `listar_por_usuario` |

**Falar:** "Quatro partes de 250 pontos. Saldo: 250 se não estiver negativo. Reserva:
proporcional ao quanto já guardou. Metas: proporção de metas concluídas. Controle de
gastos: começa em 250 e perde 80 por categoria que estourou o limite. As três primeiras
reaproveitam Services que já existem; só as metas vêm direto do Repository."

**Classificação:** abaixo de 400 Ruim, até 649 Regular, até 849 Bom, 850 ou mais
Excelente (`_classificacao`).

## 7. Alertas — aba Relatório

| Camada | Abrir |
|---|---|
| Rota | `GET /api/movimentacoes/alertas` |
| Controller | `movimentacao_controller.py` → `alertas()` |
| Service | `gerar_alertas_service.py` |
| Repository | `movimentacao_repository.py` → `ultima_data_movimentacao` e `gastos_por_categoria`; `limite_categoria_repository.py` → `listar_por_usuario` |

**Falar:** "Dois alertas. Inatividade: o Repository busca a data do último gasto com
`ORDER BY data DESC LIMIT 1`; se passou de 3 dias, alerta. Limite: o Repository soma os
gastos do mês por categoria com `GROUP BY categoria`, e a Service compara cada total com
o limite que a pessoa definiu."

---

## Se perguntarem "como vocês sabem que está certo?"

Abra `backend/tests/test_calculos_financeiros.py` (ou `test_reserva_emergencia.py`) e
leia o nome de um teste. Os nomes descrevem o comportamento garantido. Os testes rodam
com `python -m unittest` na pasta `backend`.

## Se travar

Diga em qual Service a resposta está ("isso fica na Service de score") e use o
Ctrl+P com uma palavra do nome. Mostrar que sabe onde procurar já responde metade da
pergunta.
