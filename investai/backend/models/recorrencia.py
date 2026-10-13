from .base import ModeloBase, db


class Recorrencia(ModeloBase):
    """Receita ou despesa que se repete todo mês (aluguel, assinatura,
    salário). O sistema lança a movimentação sozinho no dia combinado,
    para o usuário não precisar registrar a mesma conta todo mês - a
    "atualização manual constante" foi o motivo de abandono das planilhas
    na tabela de observação do relatório."""

    __tablename__ = "recorrencia"

    descricao = db.Column(db.String(120), nullable=False)
    tipo = db.Column(db.String(10), nullable=False, default="gasto")  # renda ou gasto
    valor = db.Column(db.Float, nullable=False)
    categoria = db.Column(db.String(40), nullable=False, default="outros")
    # Dia do lançamento (1 a 31). Em meses mais curtos vale o último dia.
    dia_mes = db.Column(db.Integer, nullable=False)
    # Nada é lançado antes desta data ('AAAA-MM-DD').
    data_inicio = db.Column(db.String(10), nullable=False)
    ativa = db.Column(db.Boolean, nullable=False, default=True)
    # Último mês já lançado ('AAAA-MM'). É o que impede lançar duas vezes
    # a mesma conta quando chegam várias requisições ao mesmo tempo.
    ultimo_mes_lancado = db.Column(db.String(7))

    usuario_id = db.Column(
        db.Integer, db.ForeignKey("usuario.id"), nullable=False
    )
    usuario = db.relationship("Usuario", back_populates="recorrencias")

    def atualizar(self, descricao=None, tipo=None, valor=None, categoria=None,
                  dia_mes=None, data_inicio=None, ativa=None):
        """UPDATE: altera apenas os campos informados."""
        if descricao is not None:
            self.descricao = descricao
        if tipo is not None:
            self.tipo = tipo
        if valor is not None:
            self.valor = valor
        if categoria is not None:
            self.categoria = categoria
        if dia_mes is not None:
            self.dia_mes = dia_mes
        if data_inicio is not None:
            self.data_inicio = data_inicio
        if ativa is not None:
            self.ativa = ativa
        return self.salvar()

    def to_dict(self):
        return {
            "id": self.id,
            "descricao": self.descricao,
            "tipo": self.tipo,
            "valor": self.valor,
            "categoria": self.categoria,
            "dia_mes": self.dia_mes,
            "data_inicio": self.data_inicio,
            "ativa": self.ativa,
            "ultimo_mes_lancado": self.ultimo_mes_lancado,
            "usuario_id": self.usuario_id,
        }

    def __repr__(self):
        return f"<Recorrencia {self.descricao} (dia {self.dia_mes})>"
