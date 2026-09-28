from models import Usuario
from repositories import MovimentacaoRepository


class CalcularDespesaMediaService:
    """Despesa mensal usada por RF09 (sobrevivência) e RF14/RF15 (reserva).

    Prioriza sempre o gasto real registrado. A estimativa informada no
    cadastro só entra enquanto não existe despesa registrada - do
    contrário, um usuário recém-criado teria despesa zero e a meta da
    reserva nasceria zerada, travando a trilha de investimentos.
    """

    def executar(self, usuario_id, meses=3):
        media_real = MovimentacaoRepository.media_gastos_mensais(usuario_id, meses=meses)
        if media_real > 0:
            return media_real

        usuario = Usuario.buscar_por_id(usuario_id)
        return usuario.despesa_mensal_estimada if usuario else 0.0
