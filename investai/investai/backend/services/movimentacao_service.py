from models import Movimentacao
from repositories import MovimentacaoRepository


class MovimentacaoService:

    @staticmethod
    def listar_todos():
        return Movimentacao.listar()

    @staticmethod
    def buscar_por_id(id):
        return Movimentacao.buscar(id)

    @staticmethod
    def criar(dados):
        movimentacao = Movimentacao(
            descricao=dados.get("descricao"),
            tipo=dados.get("tipo"),
            valor=float(dados.get("valor") or 0),
            data=dados.get("data"),
            usuario_id=int(dados.get("usuario_id")),
        )
        return movimentacao.salvar()

    @staticmethod
    def atualizar(id, dados):
        movimentacao = Movimentacao.buscar(id)
        if not movimentacao:
            return None
        movimentacao.descricao = dados.get("descricao", movimentacao.descricao)
        movimentacao.tipo = dados.get("tipo", movimentacao.tipo)
        if dados.get("valor") is not None:
            movimentacao.valor = float(dados.get("valor"))
        movimentacao.data = dados.get("data", movimentacao.data)
        if dados.get("usuario_id"):
            movimentacao.usuario_id = int(dados.get("usuario_id"))
        return movimentacao.salvar()

    @staticmethod
    def deletar(id):
        movimentacao = Movimentacao.buscar(id)
        if not movimentacao:
            return False
        movimentacao.deletar()
        return True

    @staticmethod
    def listar_por_usuario(usuario_id):
        return MovimentacaoRepository.listar_por_usuario(usuario_id)

    @staticmethod
    def saldo_do_usuario(usuario_id):
        rendas = MovimentacaoRepository.somar_por_tipo(usuario_id, "renda")
        gastos = MovimentacaoRepository.somar_por_tipo(usuario_id, "gasto")
        return rendas - gastos

    @staticmethod
    def extrato(usuario_id, tipo=None, data_inicio=None, data_fim=None, ordenar="data_desc"):
        return MovimentacaoRepository.extrato(
            usuario_id, tipo=tipo, data_inicio=data_inicio, data_fim=data_fim, ordenar=ordenar
        )
