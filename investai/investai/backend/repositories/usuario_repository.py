from models import Usuario


class UsuarioRepository:
    """Consultas específicas de Usuario que vão além do CRUD básico."""

    @staticmethod
    def buscar_por_email(email):
        return Usuario.query.filter_by(email=email).first()

    @staticmethod
    def listar_por_perfil(perfil_risco):
        return Usuario.query.filter_by(perfil_risco=perfil_risco).all()
