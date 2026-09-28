from models import Usuario
from repositories import MovimentacaoRepository
from services.movimentacao.calcular_despesa_media_service import (
    CalcularDespesaMediaService,
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

    Usa os gastos reais por categoria quando existem; enquanto não existem,
    cai para a estimativa informada no cadastro.
    """

    def executar(self, usuario_id):
        usuario = Usuario.buscar_por_id(usuario_id)
        if not usuario:
            return None

        despesa_total = CalcularDespesaMediaService().executar(usuario_id)
        obrigatoria, flexivel, maior_flexivel = self._compor(usuario_id, usuario, despesa_total)

        renda = usuario.renda_mensal or 0.0
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
        por_categoria = MovimentacaoRepository.gastos_por_categoria(usuario_id)

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
            if soma > 0:
                obrigatoria = despesa_total * (obrigatoria / soma)
                flexivel = despesa_total * (flexivel / soma)

            maior = max(flexiveis, key=lambda i: i["total"], default=None)
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
