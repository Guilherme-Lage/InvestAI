from .base import ModeloBase, db


class TokenRevogado(ModeloBase):
    """Registra o 'jti' (identificador único) de cada token JWT que foi
    invalidado por logout. Sem essa tabela, um JWT continuaria válido até
    expirar mesmo depois do usuário sair do app — o que não seria um
    logout seguro de verdade (RF02)."""

    __tablename__ = "token_revogado"

    jti = db.Column(db.String(36), nullable=False, unique=True, index=True)
    usuario_id = db.Column(db.Integer, db.ForeignKey("usuario.id"), nullable=False)

    def __repr__(self):
        return f"<TokenRevogado {self.jti}>"
