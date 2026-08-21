from models import Usuario
from repositories import MetaRepository
from services.movimentacao.calcular_saldo_service import CalcularSaldoService
from services.movimentacao.gerar_alertas_service import GerarAlertasService
from services.meta.calcular_status_reserva_emergencia_service import CalcularStatusReservaEmergenciaService


class CalcularScoreFinanceiroService:
    """RF20 - score financeiro (0 a 1000, no padrão de score de crédito
    brasileiro), combinando saldo, reserva de emergência, cumprimento
    de metas e controle de gastos (limites de categoria)."""

    def executar(self, usuario_id):
        usuario = Usuario.buscar(usuario_id)
        if not usuario:
            return None

        # 1) Saldo (0-250 pts): saldo positivo pontua cheio.
        saldo = CalcularSaldoService().executar(usuario_id)
        pontos_saldo = 250.0 if saldo >= 0 else 0.0

        # 2) Reserva de emergência (0-250 pts): proporcional ao progresso
        # rumo aos 3x da despesa média mensal.
        reserva = CalcularStatusReservaEmergenciaService().executar(usuario_id)
        if reserva["valor_ideal_reserva"] > 0:
            progresso_reserva = min(reserva["valor_guardado"] / reserva["valor_ideal_reserva"], 1.0)
        else:
            progresso_reserva = 1.0 if reserva["possui_reserva"] else 0.0
        pontos_reserva = 250.0 * progresso_reserva

        # 3) Cumprimento de metas (0-250 pts): proporção de metas concluídas.
        metas = MetaRepository.listar_por_usuario(usuario_id)
        metas_gerais = [m for m in metas if m.tipo != "reserva_emergencia"]
        if metas_gerais:
            concluidas = sum(1 for m in metas_gerais if m.valor_atual >= m.valor_alvo)
            pontos_metas = 250.0 * (concluidas / len(metas_gerais))
        else:
            pontos_metas = 0.0

        # 4) Controle de gastos (0-250 pts): desconta pontos por categoria
        # que ultrapassou o limite definido (RF13).
        alertas = GerarAlertasService().executar(usuario_id)
        qtd_estouros = len(alertas["alertas_categoria"])
        pontos_gastos = max(250.0 - (qtd_estouros * 80.0), 0.0)

        score = round(pontos_saldo + pontos_reserva + pontos_metas + pontos_gastos)

        return {
            "score": score,
            "score_maximo": 1000,
            "classificacao": self._classificacao(score),
            "detalhes": {
                "saldo": round(pontos_saldo, 1),
                "reserva_emergencia": round(pontos_reserva, 1),
                "cumprimento_metas": round(pontos_metas, 1),
                "controle_gastos": round(pontos_gastos, 1),
            },
        }

    def _classificacao(self, score):
        if score < 400:
            return "Ruim"
        if score < 650:
            return "Regular"
        if score < 850:
            return "Bom"
        return "Excelente"
