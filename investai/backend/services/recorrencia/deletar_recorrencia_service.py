from models import Recorrencia


class DeletarRecorrenciaService:
    """Exclui a recorrência. O que ela já lançou continua no histórico."""

    def executar(self, recorrencia_id, usuario_id):
        recorrencia = Recorrencia.buscar_por_id(recorrencia_id)
        if not recorrencia or recorrencia.usuario_id != usuario_id:
            return False

        recorrencia.deletar()
        return True
