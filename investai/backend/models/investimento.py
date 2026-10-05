from datetime import date

from .base import ModeloBase, db


class Investimento(ModeloBase):
    __tablename__ = "investimento"

    nome = db.Column(db.String(120), nullable=False)
    tipo = db.Column(db.String(40), nullable=False)  # ex.: Tesouro Selic, CDB, LCI
    valor_aplicado = db.Column(db.Float, nullable=False)
    rendimento_atual = db.Column(db.Float, nullable=False, default=0.0)
    liquidez = db.Column(db.String(40), nullable=False, default="diaria")

    # Com estes três o rendimento passa a ser calculado sozinho a partir das
    # taxas oficiais, em vez de depender do usuário atualizar na mão - o que
    # na prática ninguém faz. Sem indexador, vale o rendimento_atual digitado.
    indexador = db.Column(db.String(20))            # selic, cdi, ipca, poupanca
    percentual_indexador = db.Column(db.Float, nullable=False, default=100.0)
    data_aplicacao = db.Column(db.Date, nullable=False, default=date.today)

    usuario_id = db.Column(
        db.Integer, db.ForeignKey("usuario.id"), nullable=False
    )
    usuario = db.relationship("Usuario", back_populates="investimentos")

    def atualizar(self, nome=None, tipo=None, valor_aplicado=None, rendimento_atual=None,
                  liquidez=None, indexador=None, percentual_indexador=None,
                  data_aplicacao=None):
        """UPDATE: altera apenas os campos informados."""
        if nome is not None:
            self.nome = nome
        if tipo is not None:
            self.tipo = tipo
        if valor_aplicado is not None:
            self.valor_aplicado = valor_aplicado
        if rendimento_atual is not None:
            self.rendimento_atual = rendimento_atual
        if liquidez is not None:
            self.liquidez = liquidez
        if indexador is not None:
            self.indexador = indexador
        if percentual_indexador is not None:
            self.percentual_indexador = percentual_indexador
        if data_aplicacao is not None:
            self.data_aplicacao = data_aplicacao
        return self.salvar()

    def to_dict(self):
        return {
            "id": self.id,
            "nome": self.nome,
            "tipo": self.tipo,
            "valor_aplicado": self.valor_aplicado,
            "rendimento_atual": self.rendimento_atual,
            "liquidez": self.liquidez,
            "indexador": self.indexador,
            "percentual_indexador": self.percentual_indexador,
            "data_aplicacao": self.data_aplicacao.isoformat() if self.data_aplicacao else None,
            "usuario_id": self.usuario_id,
        }

    def __repr__(self):
        return f"<Investimento {self.nome}>"
