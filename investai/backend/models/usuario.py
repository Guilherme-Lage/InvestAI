from werkzeug.security import check_password_hash, generate_password_hash

from .base import ModeloBase, db


class Usuario(ModeloBase):
    __tablename__ = "usuario"

    nome = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(120), nullable=False, unique=True)
    senha_hash = db.Column(db.String(255), nullable=False)
    perfil_risco = db.Column(db.String(20), nullable=False, default="conservador")
    renda_mensal = db.Column(db.Float, nullable=False, default=0.0)

    movimentacoes = db.relationship(
        "Movimentacao", back_populates="usuario", cascade="all, delete-orphan"
    )
    investimentos = db.relationship(
        "Investimento", back_populates="usuario", cascade="all, delete-orphan"
    )
    metas = db.relationship(
        "Meta", back_populates="usuario", cascade="all, delete-orphan"
    )
    limites_categoria = db.relationship(
        "LimiteCategoria", back_populates="usuario", cascade="all, delete-orphan"
    )

    def definir_senha(self, senha_texto_puro):
        """Gera e armazena o hash da senha. A senha em texto puro nunca
        é persistida no banco (RF01/RF02 - cadastro e login seguros)."""
        self.senha_hash = generate_password_hash(senha_texto_puro)

    def verificar_senha(self, senha_texto_puro):
        """Compara a senha informada com o hash armazenado."""
        if not self.senha_hash:
            return False
        return check_password_hash(self.senha_hash, senha_texto_puro)

    def to_dict(self):
        # senha_hash NUNCA é exposto pela API.
        return {
            "id": self.id,
            "nome": self.nome,
            "email": self.email,
            "perfil_risco": self.perfil_risco,
            "renda_mensal": self.renda_mensal,
        }

    def __repr__(self):
        return f"<Usuario {self.nome}>"
