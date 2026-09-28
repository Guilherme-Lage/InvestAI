from repositories import MetaRepository
from services.movimentacao.calcular_despesa_media_service import (
    CalcularDespesaMediaService,
)
from services.investimento.sugerir_onde_guardar_reserva_service import (
    SugerirOndeGuardarReservaService,
)

MULTIPLICADOR_RESERVA_EMERGENCIA = 3  # RF14/RF15 - 3x a despesa média mensal


class CalcularStatusReservaEmergenciaService:
    """RF14/RF15 - status da reserva de emergência do usuário: quanto
    ele já tem guardado, qual é a meta ideal (3x a despesa média mensal)
    e se as sugestões de investimento já estão liberadas."""

    def executar(self, usuario_id):
        despesa_media = CalcularDespesaMediaService().executar(usuario_id)
        alvo_ideal = despesa_media * MULTIPLICADOR_RESERVA_EMERGENCIA

        reserva = MetaRepository.buscar_reserva_emergencia(usuario_id)
        valor_guardado = reserva["valor_atual"] if reserva else 0.0

        liberado = alvo_ideal > 0 and valor_guardado >= alvo_ideal

        status = {
            "possui_reserva": reserva is not None,
            "reserva": reserva,
            "despesa_media_mensal": round(despesa_media, 2),
            "valor_ideal_reserva": round(alvo_ideal, 2),
            "valor_guardado": round(valor_guardado, 2),
            "sugestoes_investimento_liberadas": liberado,
        }

        # Enquanto a reserva não está completa, o dinheiro dela precisa ficar
        # em algum lugar: parado na conta ele perde para a inflação.
        if not liberado:
            try:
                status["onde_guardar"] = SugerirOndeGuardarReservaService().executar(
                    valor_guardado
                )
            except Exception:
                status["onde_guardar"] = None  # sem taxas agora; o resto segue

        return status
