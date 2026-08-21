from models import TokenRevogado


class LogoutUsuarioService:
    """RF02 - Logout seguro: revoga o token atual (jti) para que ele não
    possa mais ser reutilizado, mesmo antes de expirar."""

    def executar(self, usuario_id, token_jti):
        if not TokenRevogado.query.filter_by(jti=token_jti).first():
            TokenRevogado(jti=token_jti, usuario_id=usuario_id).salvar()
