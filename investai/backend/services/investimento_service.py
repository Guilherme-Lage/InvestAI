from models import Investimento
from repositories import InvestimentoRepository


class InvestimentoService:

    @staticmethod
    def listar_todos():
        return Investimento.listar()

    @staticmethod
    def buscar_por_id(id):
        return Investimento.buscar(id)

    @staticmethod
    def criar(dados):
        investimento = Investimento(
            nome=dados.get("nome"),
            tipo=dados.get("tipo"),
            valor_aplicado=float(dados.get("valor_aplicado") or 0),
            rendimento_atual=float(dados.get("rendimento_atual") or 0),
            liquidez=dados.get("liquidez", "diaria"),
            usuario_id=int(dados.get("usuario_id")),
        )
        return investimento.salvar()

    @staticmethod
    def atualizar(id, dados):
        investimento = Investimento.buscar(id)
        if not investimento:
            return None
        investimento.nome = dados.get("nome", investimento.nome)
        investimento.tipo = dados.get("tipo", investimento.tipo)
        if dados.get("valor_aplicado") is not None:
            investimento.valor_aplicado = float(dados.get("valor_aplicado"))
        if dados.get("rendimento_atual") is not None:
            investimento.rendimento_atual = float(dados.get("rendimento_atual"))
        investimento.liquidez = dados.get("liquidez", investimento.liquidez)
        if dados.get("usuario_id"):
            investimento.usuario_id = int(dados.get("usuario_id"))
        return investimento.salvar()

    @staticmethod
    def deletar(id):
        investimento = Investimento.buscar(id)
        if not investimento:
            return False
        investimento.deletar()
        return True

    @staticmethod
    def listar_por_usuario(usuario_id):
        return InvestimentoRepository.listar_por_usuario(usuario_id)

    @staticmethod
    def total_aplicado(usuario_id):
        return InvestimentoRepository.total_aplicado(usuario_id)
