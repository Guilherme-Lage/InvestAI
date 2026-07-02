from .base import ModeloBase, db


class Meta(ModeloBase):
    __tablename__ = "meta"

    titulo = db.Column(db.String(120), nullable=False)
    valor_alvo = db.Column(db.Float, nullable=False)
    valor_atual = db.Column(db.Float, nullable=False, default=0.0)
    prazo = db.Column(db.String(20), nullable=False)

    usuario_id = db.Column(
        db.Integer, db.ForeignKey("usuario.id"), nullable=False
    )
    usuario = db.relationship("Usuario", back_populates="metas")

    @property
    def progresso(self):
        if self.valor_alvo <= 0:
            return 0
        return round((self.valor_atual / self.valor_alvo) * 100, 1)

    def to_dict(self):
        return {
            "id": self.id,
            "titulo": self.titulo,
            "valor_alvo": self.valor_alvo,
            "valor_atual": self.valor_atual,
            "prazo": self.prazo,
            "progresso": self.progresso,
            "usuario_id": self.usuario_id,
        }

    def __repr__(self):
        return f"<Meta {self.titulo}>"
