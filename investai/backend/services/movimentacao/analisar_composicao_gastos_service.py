from models import Usuario
from repositories import MovimentacaoRepository
from repositories.movimentacao_repository import CATEGORIA_AJUSTE_SALDO
from services.movimentacao.calcular_despesa_media_service import (
    CalcularDespesaMediaService,
)
from services.movimentacao.calcular_renda_media_service import (
    CalcularRendaMediaService,
)

# Categorias que a pessoa não consegue cortar no curto prazo sem uma
# mudança grande de vida (mudar de casa, tirar o filho da escola). O guia
# (RF16) precisa dessa distinção: mandar "corte gastos" para quem só tem
# despesa obrigatória não ajuda e ainda soa como julgamento.
CATEGORIAS_OBRIGATORIAS = {"contas_fixas", "transporte", "saude", "educacao"}

# Abaixo disso a sobra mensal é pequena demais para construir reserva em
# tempo razoável, e o guia muda de tom.
PERCENTUAL_CAPACIDADE_BAIXA = 10.0

# Só faz sentido sugerir corte se a parte flexível for relevante frente ao
# total gasto - senão o corte não move o ponteiro.
PERCENTUAL_FLEXIVEL_RELEVANTE = 15.0


class AnalisarComposicaoGastosService:
    """Separa a despesa do usuário entre obrigatória e flexível e diz onde
    está a alavanca real dele: cortar gasto flexível, aumentar renda, ou
    seguir no ritmo atual.

    Usa a renda e os gastos reais quando existem; enquanto não existem,
    cai para o que foi informado no cadastro. Todos os valores devolvidos
    são mensais.
    """

    def executar(self, usuario_id):
        usuario = Usuario.buscar_por_id(usuario_id)
        if not usuario:
            return None

        despesa_total = CalcularDespesaMediaService().executar(usuario_id)
        obrigatoria, flexivel, maior_flexivel = self._compor(usuario_id, usuario, despesa_total)

        renda = CalcularRendaMediaService().executar(usuario_id)
        capacidade = renda - despesa_total
        percentual = (capacidade / renda * 100) if renda > 0 else 0.0

        return {
            "renda_mensal": round(renda, 2),
            "despesa_mensal": round(despesa_total, 2),
            "despesa_obrigatoria": round(obrigatoria, 2),
            "despesa_flexivel": round(flexivel, 2),
            "capacidade_mensal": round(capacidade, 2),
            "percentual_capacidade": round(percentual, 1),
            "maior_gasto_flexivel": maior_flexivel,
            "foco": self._definir_foco(percentual, despesa_total, flexivel),
        }

    def _compor(self, usuario_id, usuario, despesa_total):
        """Divide a despesa entre obrigatória e flexível, e aponta a maior
        categoria flexível (a que faz diferença se for ajustada)."""
        # O ajuste de saldo da importação não é um gasto de verdade: sem
        # este filtro ele podia virar o "maior gasto ajustável" do guia.
        por_categoria = [
            item for item in MovimentacaoRepository.gastos_por_categoria(usuario_id)
            if item["categoria"] != CATEGORIA_AJUSTE_SALDO
        ]

        if por_categoria:
            obrigatoria = sum(
                item["total"] for item in por_categoria
                if item["categoria"] in CATEGORIAS_OBRIGATORIAS
            )
            flexiveis = [
                item for item in por_categoria
                if item["categoria"] not in CATEGORIAS_OBRIGATORIAS
            ]
            flexivel = sum(item["total"] for item in flexiveis)

            # Os totais por categoria são do histórico inteiro, enquanto a
            # despesa usada nos cálculos é mensal - normaliza a proporção
            # para os dois falarem da mesma escala.
            soma = obrigatoria + flexivel
            fator = despesa_total / soma if soma > 0 else 0.0
            obrigatoria *= fator
            flexivel *= fator

            # A maior categoria também vai na escala mensal: o guia mostra
            # esse valor como "seu maior gasto", e o total do histórico
            # inteiro parecia um gasto de um mês só.
            maior = max(flexiveis, key=lambda i: i["total"], default=None)
            if maior:
                maior = {"categoria": maior["categoria"], "total": round(maior["total"] * fator, 2)}
            return obrigatoria, flexivel, maior

        # Sem histórico: usa o que foi informado no cadastro.
        obrigatoria = usuario.despesa_fixa_estimada or 0.0
        flexivel = max(despesa_total - obrigatoria, 0.0)
        return obrigatoria, flexivel, None

    def _definir_foco(self, percentual, despesa_total, flexivel):
        if percentual >= PERCENTUAL_CAPACIDADE_BAIXA:
            return "no_ritmo"

        proporcao_flexivel = (flexivel / despesa_total * 100) if despesa_total > 0 else 0.0
        if proporcao_flexivel >= PERCENTUAL_FLEXIVEL_RELEVANTE:
            return "reduzir_flexivel"

        # Quase tudo é obrigatório: cortar não resolve, a alavanca é renda.
        return "aumentar_renda"
