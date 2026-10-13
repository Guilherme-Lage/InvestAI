from datetime import date

from models import Recorrencia
from services.recorrencia.lancar_recorrencias_pendentes_service import (
    LancarRecorrenciasPendentesService,
)
from services.recorrencia.validar_recorrencia import validar_campos


class AtualizarRecorrenciaService:
    """Edita uma recorrência ou a pausa/retoma (campo `ativa`). As
    movimentações já lançadas não mudam: a alteração vale dali em diante."""

    def executar(self, recorrencia_id, usuario_id, dados):
        recorrencia = Recorrencia.buscar_por_id(recorrencia_id)
        if not recorrencia or recorrencia.usuario_id != usuario_id:
            return None

        campos = validar_campos(dados, parcial=True)

        ativa = dados.get("ativa")
        if ativa is not None:
            ativa = bool(ativa)
            if ativa and not recorrencia.ativa:
                # Ao retomar, recomeça de hoje: os meses em que ficou
                # pausada não devem ser lançados de uma vez.
                campos["data_inicio"] = date.today().isoformat()

        recorrencia.atualizar(ativa=ativa, **campos)

        LancarRecorrenciasPendentesService().executar(usuario_id)
        return recorrencia.to_dict()
