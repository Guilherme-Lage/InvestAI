from .base import ModeloBase, db


class TransacaoImportada(ModeloBase):
    """Marca que uma linha de extrato bancário já virou movimentação.

    Quem importa o extrato a cada 15 dias sempre traz um pedaço do período
    anterior junto. Cada transação do banco tem um identificador próprio;
    guardando os que já entraram, importar o mesmo trecho de novo não
    duplica nada.
    """

    __tablename__ = "transacao_importada"
    __table_args__ = (
        db.UniqueConstraint("usuario_id", "identificador", name="uq_importada_usuario_identificador"),
    )

    # Identificador da transação no extrato (banco + conta + código do banco).
    identificador = db.Column(db.String(200), nullable=False)

    # Lançamento que esta linha gerou. Se o usuário apagar o lançamento, a
    # marca sai junto e a linha pode ser importada de novo - um erro na
    # importação não fica sem conserto. Vazio nas marcas gravadas antes
    # desta coluna existir.
    movimentacao_id = db.Column(db.Integer, db.ForeignKey("movimentacao.id"), index=True)

    usuario_id = db.Column(
        db.Integer, db.ForeignKey("usuario.id"), nullable=False
    )
    usuario = db.relationship("Usuario", back_populates="transacoes_importadas")

    def __repr__(self):
        return f"<TransacaoImportada {self.identificador}>"
