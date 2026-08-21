from models import Usuario
from services.movimentacao.calcular_saldo_service import CalcularSaldoService
from services.meta.calcular_status_reserva_emergencia_service import (
    CalcularStatusReservaEmergenciaService,
    MULTIPLICADOR_RESERVA_EMERGENCIA,
)
from services.mercado.buscar_taxas_mercado_service import BuscarTaxasMercadoService

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
            mensagem = (
                f"Antes de investir, junte uma reserva de emergência equivalente a "
                f"{MULTIPLICADOR_RESERVA_EMERGENCIA}x sua despesa "
                f"média mensal (R$ {reserva['valor_ideal_reserva']:.2f}). "
                f"Faltam R$ {faltante:.2f}."
            )
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

        if passo == "pronto_para_investir":
            resultado["sugestoes_investimento"] = self._montar_sugestoes(usuario.perfil_risco)

        return resultado

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
