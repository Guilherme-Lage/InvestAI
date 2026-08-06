from .base import ModeloBase, db


class Usuario(ModeloBase):
    __tablename__ = "usuario"

    nome = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(120), nullable=False, unique=True)
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

    def to_dict(self):
        return {
            "id": self.id,
            "nome": self.nome,
            "email": self.email,
            "perfil_risco": self.perfil_risco,
            "renda_mensal": self.renda_mensal,
        }

    def __repr__(self):
        return f"<Usuario {self.nome}>"
