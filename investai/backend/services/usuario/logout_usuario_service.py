from models import TokenRevogado
from repositories import TokenRevogadoRepository


class LogoutUsuarioService:
    """RF02 - Logout seguro: revoga o token atual (jti) para que ele não
    possa mais ser reutilizado, mesmo antes de expirar."""

    def executar(self, usuario_id, token_jti):
        if not TokenRevogadoRepository.buscar_por_jti(token_jti):
            TokenRevogado(jti=token_jti, usuario_id=usuario_id).salvar()
