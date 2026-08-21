import uuid
from datetime import datetime, timedelta, timezone

import jwt
from flask import current_app

ALGORITMO = "HS256"
HORAS_VALIDADE_TOKEN = 8


class AuthService:
    """Centraliza a criação e a validação dos tokens JWT usados para
    autenticar o usuário depois do login (RF02)."""

    @staticmethod
    def gerar_token(usuario_id):
        agora = datetime.now(timezone.utc)
        payload = {
            "sub": str(usuario_id),
            "jti": str(uuid.uuid4()),  # identificador único do token, usado no logout
            "iat": agora,
            "exp": agora + timedelta(hours=HORAS_VALIDADE_TOKEN),
        }
        return jwt.encode(payload, current_app.config["SECRET_KEY"], algorithm=ALGORITMO)

    @staticmethod
    def decodificar_token(token):
        """Levanta jwt.ExpiredSignatureError ou jwt.InvalidTokenError
        quando o token não é válido; quem chama deve tratar."""
        return jwt.decode(token, current_app.config["SECRET_KEY"], algorithms=[ALGORITMO])
