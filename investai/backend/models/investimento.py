from .base import ModeloBase, db


class Investimento(ModeloBase):
    __tablename__ = "investimento"

    nome = db.Column(db.String(120), nullable=False)
    tipo = db.Column(db.String(40), nullable=False)  # ex.: Tesouro Selic, CDB, LCI
    valor_aplicado = db.Column(db.Float, nullable=False)
    rendimento_atual = db.Column(db.Float, nullable=False, default=0.0)
    liquidez = db.Column(db.String(40), nullable=False, default="diaria")

    usuario_id = db.Column(
        db.Integer, db.ForeignKey("usuario.id"), nullable=False
    )
    usuario = db.relationship("Usuario", back_populates="investimentos")

    def to_dict(self):
        return {
            "id": self.id,
            "nome": self.nome,
            "tipo": self.tipo,
            "valor_aplicado": self.valor_aplicado,
            "rendimento_atual": self.rendimento_atual,
            "liquidez": self.liquidez,
            "usuario_id": self.usuario_id,
        }

    def __repr__(self):
        return f"<Investimento {self.nome}>"
