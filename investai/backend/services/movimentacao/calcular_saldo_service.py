from repositories import MovimentacaoRepository


class CalcularSaldoService:
    """RF05 - saldo disponível (rendas - gastos), sempre calculado na
    hora a partir de todas as movimentações do usuário."""

    def executar(self, usuario_id):
        rendas = MovimentacaoRepository.somar_por_tipo(usuario_id, "renda")
        gastos = MovimentacaoRepository.somar_por_tipo(usuario_id, "gasto")
        return rendas - gastos
