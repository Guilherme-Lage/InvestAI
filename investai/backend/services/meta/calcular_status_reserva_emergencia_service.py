from repositories import MetaRepository, MovimentacaoRepository

MULTIPLICADOR_RESERVA_EMERGENCIA = 3  # RF14/RF15 - 3x a despesa média mensal


class CalcularStatusReservaEmergenciaService:
    """RF14/RF15 - status da reserva de emergência do usuário: quanto
    ele já tem guardado, qual é a meta ideal (3x a despesa média mensal)
    e se as sugestões de investimento já estão liberadas."""

    def executar(self, usuario_id):
        despesa_media = MovimentacaoRepository.media_gastos_mensais(usuario_id, meses=3)
        alvo_ideal = despesa_media * MULTIPLICADOR_RESERVA_EMERGENCIA

        reserva = MetaRepository.buscar_reserva_emergencia(usuario_id)
        valor_guardado = reserva.valor_atual if reserva else 0.0

        liberado = alvo_ideal > 0 and valor_guardado >= alvo_ideal

        return {
            "possui_reserva": reserva is not None,
            "reserva": reserva.to_dict() if reserva else None,
            "despesa_media_mensal": round(despesa_media, 2),
            "valor_ideal_reserva": round(alvo_ideal, 2),
            "valor_guardado": round(valor_guardado, 2),
            "sugestoes_investimento_liberadas": liberado,
        }
