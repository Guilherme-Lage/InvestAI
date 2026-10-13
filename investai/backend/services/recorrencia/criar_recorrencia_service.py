from models import Recorrencia
from services.recorrencia.lancar_recorrencias_pendentes_service import (
    LancarRecorrenciasPendentesService,
)
from services.recorrencia.validar_recorrencia import validar_campos


class CriarRecorrenciaService:
    """Cadastra uma receita ou despesa que se repete todo mês. Se o dia
    do lançamento já chegou, a primeira movimentação é gerada na hora."""

    def executar(self, usuario_id, dados):
        campos = validar_campos(dados)

        recorrencia = Recorrencia(usuario_id=usuario_id, ativa=True, **campos)
        recorrencia.salvar()

        LancarRecorrenciasPendentesService().executar(usuario_id)
        return recorrencia.to_dict()
