from werkzeug.security import check_password_hash

from models import Usuario
from repositories import UsuarioRepository
from services.auth_service import AuthService
from services.erros import ErroAutenticacao
from services.usuario.conta_demo import iniciar_sessao_demo


class AutenticarUsuarioService:
    """RF02 - Login seguro: confere e-mail + hash de senha e emite um
    token JWT que o app deve enviar em 'Authorization: Bearer <token>'."""

    def executar(self, email, senha):
        email = (email or "").strip().lower()
        senha = senha or ""

        if not email or not senha:
            raise ValueError("Informe e-mail e senha.")

        usuario = UsuarioRepository.buscar_por_email(email)
        if not usuario or not check_password_hash(usuario["senha_hash"], senha):
            raise ErroAutenticacao("E-mail ou senha incorretos.")

        token = AuthService.gerar_token(usuario["id"])
        # Conta de demonstração: cada login devolve o questionário (pendente)
        # e a reserva de emergência ao estado original da apresentação.
        iniciar_sessao_demo(usuario["id"])
        # Mesmo formato de /me (to_dict, que nunca expõe o senha_hash), para o
        # app receber também se o questionário de suitability foi respondido.
        return {"usuario": Usuario.buscar_por_id(usuario["id"]).to_dict(), "token": token}
