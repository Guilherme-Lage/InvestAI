from datetime import datetime

from models import Usuario
from services.usuario.questionario_suitability import VERSAO_ATUAL, avaliar_respostas


class ResponderSuitabilityService:
    """RF18 - o perfil de investidor vem do questionário de suitability.

    Calcula o perfil a partir das respostas e grava no usuário. Serve
    tanto para quem pulou o questionário no cadastro quanto para quem
    quer refazê-lo depois."""

    def executar(self, usuario_id, respostas):
        usuario = Usuario.buscar_por_id(usuario_id)
        if usuario is None:
            return None

        avaliacao = avaliar_respostas(respostas)
        usuario.registrar_suitability(
            perfil=avaliacao["perfil"],
            pontuacao=avaliacao["pontuacao"],
            versao=VERSAO_ATUAL,
            quando=datetime.now(),
        )
        return {"usuario": usuario.to_dict(), "resultado": avaliacao}
