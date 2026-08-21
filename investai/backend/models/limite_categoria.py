from .base import ModeloBase, db


class LimiteCategoria(ModeloBase):
    """Limite de gasto mensal que o usuário define para uma categoria
    (ex.: 'lazer' até R$ 300/mês). Usado para o alerta de estouro de
    limite por categoria (RF13)."""

    __tablename__ = "limite_categoria"
    __table_args__ = (
        db.UniqueConstraint("usuario_id", "categoria", name="uq_limite_usuario_categoria"),
    )

    categoria = db.Column(db.String(40), nullable=False)
    valor_limite = db.Column(db.Float, nullable=False)

    usuario_id = db.Column(
        db.Integer, db.ForeignKey("usuario.id"), nullable=False
    )
    usuario = db.relationship("Usuario", back_populates="limites_categoria")

    def atualizar(self, valor_limite=None):
        """UPDATE: altera apenas os campos informados."""
        if valor_limite is not None:
            self.valor_limite = valor_limite
        return self.salvar()

    def to_dict(self):
        return {
            "id": self.id,
            "categoria": self.categoria,
            "valor_limite": self.valor_limite,
            "usuario_id": self.usuario_id,
        }

    def __repr__(self):
        return f"<LimiteCategoria {self.categoria} ({self.valor_limite})>"
