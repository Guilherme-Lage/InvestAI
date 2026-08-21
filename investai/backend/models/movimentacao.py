from .base import ModeloBase, db


class Movimentacao(ModeloBase):
    __tablename__ = "movimentacao"

    descricao = db.Column(db.String(120), nullable=False)
    tipo = db.Column(db.String(10), nullable=False)  # renda ou gasto
    valor = db.Column(db.Float, nullable=False)
    data = db.Column(db.String(20), nullable=False)
    # RF03/RF04 - categoria da movimentação (ex.: alimentação, lazer,
    # contas fixas, reserva, salário etc.), usada nos gráficos (RF11) e
    # nos alertas de limite por categoria (RF13).
    categoria = db.Column(db.String(40), nullable=False, default="outros")

    usuario_id = db.Column(
        db.Integer, db.ForeignKey("usuario.id"), nullable=False
    )
    usuario = db.relationship("Usuario", back_populates="movimentacoes")

    def to_dict(self):
        return {
            "id": self.id,
            "descricao": self.descricao,
            "tipo": self.tipo,
            "valor": self.valor,
            "data": self.data,
            "categoria": self.categoria,
            "usuario_id": self.usuario_id,
        }

    def __repr__(self):
        return f"<Movimentacao {self.descricao} ({self.tipo})>"
