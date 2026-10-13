from datetime import date, timedelta

from sqlalchemy.exc import IntegrityError

from models import ScoreHistorico, db
from repositories import ScoreHistoricoRepository
from services.usuario.calcular_score_financeiro_service import CalcularScoreFinanceiroService

DIAS_PADRAO = 90
DIAS_MAXIMO = 365


class ListarHistoricoScoreService:
    """Evolução do score financeiro (RF20) ao longo do tempo.

    O score depende de dados que não guardam passado (quanto havia na
    reserva, quais metas estavam concluídas), então não dá para
    reconstruí-lo para trás: o histórico é formado por um retrato por dia,
    tirado quando o usuário consulta. Dias sem consulta ficam sem ponto.
    """

    def executar(self, usuario_id, dias=None):
        dias = min(max(dias or DIAS_PADRAO, 1), DIAS_MAXIMO)
        hoje = date.today()

        atual = CalcularScoreFinanceiroService().executar(usuario_id)
        if atual is None:
            return None
        self._registrar(usuario_id, hoje.isoformat(), atual["score"])

        historico = ScoreHistoricoRepository.listar_desde(
            usuario_id, (hoje - timedelta(days=dias)).isoformat()
        )
        variacao = historico[-1]["score"] - historico[0]["score"] if historico else 0

        return {
            "dias": dias,
            "historico": historico,
            # Diferença entre o ponto mais recente e o mais antigo do período.
            "variacao": variacao,
        }

    def _registrar(self, usuario_id, data, score):
        """Grava o retrato do dia; se já houver um, fica o valor mais novo."""
        existente = ScoreHistoricoRepository.buscar_por_data(usuario_id, data)
        if existente:
            if existente["score"] != score:
                ScoreHistorico.buscar_por_id(existente["id"]).atualizar(score=score)
            return

        try:
            ScoreHistorico(usuario_id=usuario_id, data=data, score=score).salvar()
        except IntegrityError:
            # Duas consultas simultâneas no mesmo dia: a outra já gravou.
            db.session.rollback()
