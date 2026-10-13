from .base import ModeloBase, db


class ScoreHistorico(ModeloBase):
    """Retrato do score financeiro (RF20) em um dia. O score em si é
    calculado na hora e não fica guardado em lugar nenhum; sem estes
    retratos não haveria como mostrar se o usuário está melhorando."""

    __tablename__ = "score_historico"
    __table_args__ = (
        db.UniqueConstraint("usuario_id", "data", name="uq_score_usuario_data"),
    )

    data = db.Column(db.String(10), nullable=False)  # 'AAAA-MM-DD'
    score = db.Column(db.Integer, nullable=False)

    usuario_id = db.Column(
        db.Integer, db.ForeignKey("usuario.id"), nullable=False
    )
    usuario = db.relationship("Usuario", back_populates="historico_score")

    def atualizar(self, score=None):
        """UPDATE: altera apenas os campos informados."""
        if score is not None:
            self.score = score
        return self.salvar()

    def to_dict(self):
        return {
            "id": self.id,
            "data": self.data,
            "score": self.score,
            "usuario_id": self.usuario_id,
        }

    def __repr__(self):
        return f"<ScoreHistorico {self.data} ({self.score})>"
