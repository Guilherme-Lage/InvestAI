from models import Usuario
from services.movimentacao.calcular_saldo_service import CalcularSaldoService
from services.meta.calcular_status_reserva_emergencia_service import (
    CalcularStatusReservaEmergenciaService,
    MULTIPLICADOR_RESERVA_EMERGENCIA,
)
from services.mercado.buscar_taxas_mercado_service import BuscarTaxasMercadoService
from services.movimentacao.analisar_composicao_gastos_service import (
    AnalisarComposicaoGastosService,
)

ROTULOS_CATEGORIA = {
    "alimentacao": "alimentação",
    "lazer": "lazer",
    "contas_fixas": "contas fixas",
    "transporte": "transporte",
    "saude": "saúde",
    "educacao": "educação",
    "outros": "outros",
}

# RF16 - sugestões de investimento adaptadas ao perfil de investidor do
# usuário (RF18). A trilha em si é educativa e fixa (sem recomendar um
# banco/corretora específico), mas o rendimento de cada uma é enriquecido
# com a taxa oficial (Selic/CDI/IPCA) do Banco Central quando disponível
# (ver "indexador" e BuscarTaxasMercadoService).
SUGESTOES_POR_PERFIL = {
    "conservador": [
        {"nome": "Tesouro Selic", "tipo": "Renda fixa", "liquidez": "diaria", "indexador": "selic",
         "descricao_base": "Baixo risco, ótima liquidez. Bom para reserva e objetivos de curto prazo."},
        {"nome": "CDB 100% do CDI", "tipo": "Renda fixa", "liquidez": "diaria", "indexador": "cdi",
         "descricao_base": "Segurança do FGC, rendimento previsível."},
    ],
    "moderado": [
        {"nome": "Tesouro IPCA+", "tipo": "Renda fixa", "liquidez": "no vencimento", "indexador": "ipca",
         "descricao_base": "Protege da inflação, bom para metas de médio/longo prazo."},
        {"nome": "CDB/LCI de banco médio", "tipo": "Renda fixa", "liquidez": "carencia", "indexador": "cdi",
         "descricao_base": "Rendimento acima da média mantendo baixo risco."},
        {"nome": "Fundos multimercado", "tipo": "Fundo", "liquidez": "diaria", "indexador": None,
         "descricao_base": "Diversificação entre renda fixa e variável."},
    ],
    "arrojado": [
        {"nome": "Fundos de ações", "tipo": "Renda variável", "liquidez": "diaria", "indexador": None,
         "descricao_base": "Maior potencial de retorno no longo prazo, com mais volatilidade."},
        {"nome": "ETFs de índice (ex.: IBOV)", "tipo": "Renda variável", "liquidez": "diaria", "indexador": None,
         "descricao_base": "Diversificação em bolsa com um único ativo."},
        {"nome": "Fundos multimercado agressivos", "tipo": "Fundo", "liquidez": "carencia", "indexador": None,
         "descricao_base": "Maior exposição a risco em busca de retorno superior."},
    ],
}

RESUMO_INDEXADOR = {
    "selic": "Rende hoje ~{taxa:.2f}% ao ano (Taxa Selic).",
    "cdi": "Rende hoje ~{taxa:.2f}% ao ano (100% do CDI).",
    "ipca": "Rende IPCA + prêmio; a inflação (IPCA) acumulada em 12 meses está em ~{taxa:.2f}%.",
}


class GerarGuiaFinanceiroService:
    """RF16 - guia financeiro passo a passo, adaptado à situação atual
    do usuário: saldo negativo, construção de reserva, ou pronto para
    investir. Também aplica RF14/RF15 (reserva antes de investimento)."""

    def executar(self, usuario_id):
        usuario = Usuario.buscar_por_id(usuario_id)
        if not usuario:
            return None

        saldo = CalcularSaldoService().executar(usuario_id)
        reserva = CalcularStatusReservaEmergenciaService().executar(usuario_id)
        composicao = None
        faltante = 0.0

        if saldo < 0:
            passo = "saldo_negativo"
            titulo = "Organize suas contas primeiro"
            mensagem = (
                "Seus gastos estão maiores que suas receitas. Antes de pensar em "
                "reserva ou investimentos, ajuste o orçamento: registre todas as "
                "despesas por categoria e corte o que for possível."
            )
        elif not reserva["sugestoes_investimento_liberadas"]:
            passo = "construir_reserva"
            titulo = "Construa sua reserva de emergência"
            faltante = max(reserva["valor_ideal_reserva"] - reserva["valor_guardado"], 0.0)
            composicao = AnalisarComposicaoGastosService().executar(usuario_id)
            mensagem = self._mensagem_reserva(reserva, faltante, composicao)
        else:
            passo = "pronto_para_investir"
            titulo = "Você está pronto para investir"
            mensagem = (
                "Sua reserva de emergência está completa. Veja sugestões de "
                "investimento de acordo com o seu perfil."
            )

        resultado = {
            "passo": passo,
            "titulo": titulo,
            "mensagem": mensagem,
            "saldo": saldo,
            "reserva": reserva,
        }

        if passo == "construir_reserva":
            resultado["composicao_gastos"] = composicao
            resultado["meses_estimados"] = self._meses_para_juntar(faltante, composicao)

        if passo == "pronto_para_investir":
            resultado["sugestoes_investimento"] = self._montar_sugestoes(usuario.perfil_risco)

        return resultado

    def _meses_para_juntar(self, faltante, composicao):
        """Quantos meses faltam no ritmo atual. None quando não sobra nada -
        aí não existe previsão honesta a dar."""
        if not composicao or composicao["capacidade_mensal"] <= 0:
            return None
        return max(1, round(faltante / composicao["capacidade_mensal"]))

    def _mensagem_reserva(self, reserva, faltante, composicao):
        """A meta continua sendo 3x a despesa (RF14/RF15), mas o conselho
        muda conforme o motivo de a sobra ser pequena: quem tem gasto
        flexível consegue cortar, quem só tem gasto fixo não - e nesse caso
        insistir em corte seria inútil."""
        base = (
            f"Antes de investir, junte uma reserva equivalente a "
            f"{MULTIPLICADOR_RESERVA_EMERGENCIA}x sua despesa média mensal "
            f"(R$ {reserva['valor_ideal_reserva']:.2f}). "
            f"Faltam R$ {faltante:.2f}."
        )

        if not composicao:
            return base

        capacidade = composicao["capacidade_mensal"]
        foco = composicao["foco"]

        if foco == "reduzir_flexivel":
            maior = composicao["maior_gasto_flexivel"]
            # Só aponta a categoria quando existe histórico real; pela
            # estimativa do cadastro sabemos o quanto é flexível, mas não onde.
            if maior:
                onde = (
                    f" Seu maior gasto ajustável é "
                    f"{ROTULOS_CATEGORIA.get(maior['categoria'], maior['categoria'])} "
                    f"(R$ {maior['total']:.2f}) - reduzir aí é o que mais acelera "
                    f"sua reserva."
                )
            else:
                onde = (
                    f" Mas R$ {composicao['despesa_flexivel']:.2f} dos seus gastos não "
                    f"são fixos: é aí que dá para ganhar tempo. Registre suas despesas "
                    f"por categoria que eu te mostro onde cortar."
                )
            return (
                f"{base} Hoje sobram R$ {capacidade:.2f} por mês "
                f"({composicao['percentual_capacidade']:.0f}% da sua renda), o que é "
                f"pouco para essa meta.{onde}"
            )

        if foco == "aumentar_renda":
            return (
                f"{base} Das suas despesas, R$ {composicao['despesa_obrigatoria']:.2f} "
                f"são fixas (moradia, transporte, saúde, educação) - ou seja, quase "
                f"não há o que cortar, e tentar cortar não vai resolver. Sua reserva "
                f"vai ser construída devagar mesmo, e tudo bem: guarde o que der, no "
                f"seu ritmo. O que realmente muda esse cenário é aumentar a renda."
            )

        meses = self._meses_para_juntar(faltante, composicao)
        if meses:
            return (
                f"{base} Guardando os R$ {capacidade:.2f} que sobram por mês, você "
                f"chega lá em cerca de {meses} "
                f"{'mês' if meses == 1 else 'meses'}."
            )
        return base

    def _montar_sugestoes(self, perfil_risco):
        base = SUGESTOES_POR_PERFIL.get(perfil_risco, SUGESTOES_POR_PERFIL["conservador"])

        try:
            taxas = BuscarTaxasMercadoService().executar()
        except Exception:
            # Sem taxas oficiais no momento (API do Banco Central fora do ar):
            # mantém as sugestões com a descrição educativa, sem o número real.
            taxas = None

        sugestoes = []
        for item in base:
            indexador = item.get("indexador")
            descricao = item["descricao_base"]
            if indexador and taxas and taxas.get(indexador) is not None:
                descricao = f"{descricao} {RESUMO_INDEXADOR[indexador].format(taxa=taxas[indexador])}"
            sugestoes.append({
                "nome": item["nome"],
                "tipo": item["tipo"],
                "liquidez": item["liquidez"],
                "descricao": descricao,
            })
        return sugestoes
