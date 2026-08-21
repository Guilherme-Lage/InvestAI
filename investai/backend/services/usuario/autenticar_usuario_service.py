from repositories import UsuarioRepository
from services.auth_service import AuthService
from services.erros import ErroAutenticacao


class AutenticarUsuarioService:
    """RF02 - Login seguro: confere e-mail + hash de senha e emite um
    token JWT que o app deve enviar em 'Authorization: Bearer <token>'."""

    def executar(self, email, senha):
        email = (email or "").strip().lower()
        senha = senha or ""

        if not email or not senha:
            raise ValueError("Informe e-mail e senha.")

        usuario = UsuarioRepository.buscar_por_email(email)
        if not usuario or not usuario.verificar_senha(senha):
            raise ErroAutenticacao("E-mail ou senha incorretos.")

        token = AuthService.gerar_token(usuario.id)
        return {"usuario": usuario.to_dict(), "token": token}
