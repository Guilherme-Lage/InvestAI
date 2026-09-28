import re

from models import Usuario
from repositories import UsuarioRepository
from services.auth_service import AuthService

REGEX_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
TAMANHO_MINIMO_SENHA = 6


class CriarUsuarioService:
    """RF01 - Cadastro de conta com nome, e-mail e senha.

    Valida os dados, garante e-mail único e armazena a senha apenas como
    hash (nunca em texto puro). Devolve o usuário já com um token JWT,
    para que o app entre autenticado logo após o cadastro.
    """

    def executar(self, dados):
        nome = (dados.get("nome") or "").strip()
        email = (dados.get("email") or "").strip().lower()
        senha = dados.get("senha") or ""

        if len(nome) < 2:
            raise ValueError("Informe um nome válido.")
        if not REGEX_EMAIL.match(email):
            raise ValueError("Informe um e-mail válido.")
        if len(senha) < TAMANHO_MINIMO_SENHA:
            raise ValueError(
                f"A senha deve ter pelo menos {TAMANHO_MINIMO_SENHA} caracteres."
            )
        if UsuarioRepository.buscar_por_email(email):
            raise ValueError("Já existe uma conta cadastrada com esse e-mail.")

        try:
            renda_mensal = float(dados.get("renda_mensal") or 0)
        except (TypeError, ValueError):
            raise ValueError("Renda mensal inválida.")
        if renda_mensal < 0:
            raise ValueError("Renda mensal não pode ser negativa.")

        try:
            despesa_estimada = float(dados.get("despesa_mensal_estimada") or 0)
            despesa_fixa = float(dados.get("despesa_fixa_estimada") or 0)
        except (TypeError, ValueError):
            raise ValueError("Despesa mensal estimada inválida.")
        if despesa_estimada < 0 or despesa_fixa < 0:
            raise ValueError("Despesa mensal estimada não pode ser negativa.")
        if despesa_fixa > despesa_estimada:
            raise ValueError("A despesa fixa não pode ser maior que a despesa total.")

        perfil_risco = dados.get("perfil_risco", "conservador")
        if perfil_risco not in ("conservador", "moderado", "arrojado"):
            raise ValueError("Perfil de risco inválido.")

        usuario = Usuario(
            nome=nome,
            email=email,
            perfil_risco=perfil_risco,
            renda_mensal=renda_mensal,
            despesa_mensal_estimada=despesa_estimada,
            despesa_fixa_estimada=despesa_fixa,
        )
        usuario.definir_senha(senha)
        usuario.salvar()

        token = AuthService.gerar_token(usuario.id)
        return {"usuario": usuario.to_dict(), "token": token}
