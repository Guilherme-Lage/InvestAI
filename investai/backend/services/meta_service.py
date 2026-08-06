from models import Meta
from repositories import MetaRepository


class MetaService:

    @staticmethod
    def listar_todos():
        return Meta.listar()

    @staticmethod
    def buscar_por_id(id):
        return Meta.buscar(id)

    @staticmethod
    def criar(dados):
        meta = Meta(
            titulo=dados.get("titulo"),
            valor_alvo=float(dados.get("valor_alvo") or 0),
            valor_atual=float(dados.get("valor_atual") or 0),
            prazo=dados.get("prazo"),
            usuario_id=int(dados.get("usuario_id")),
        )
        return meta.salvar()

    @staticmethod
    def atualizar(id, dados):
        meta = Meta.buscar(id)
        if not meta:
            return None
        meta.titulo = dados.get("titulo", meta.titulo)
        if dados.get("valor_alvo") is not None:
            meta.valor_alvo = float(dados.get("valor_alvo"))
        if dados.get("valor_atual") is not None:
            meta.valor_atual = float(dados.get("valor_atual"))
        meta.prazo = dados.get("prazo", meta.prazo)
        if dados.get("usuario_id"):
            meta.usuario_id = int(dados.get("usuario_id"))
        return meta.salvar()

    @staticmethod
    def deletar(id):
        meta = Meta.buscar(id)
        if not meta:
            return False
        meta.deletar()
        return True

    @staticmethod
    def listar_por_usuario(usuario_id):
        return MetaRepository.listar_por_usuario(usuario_id)

    @staticmethod
    def listar_concluidas(usuario_id):
        return MetaRepository.listar_concluidas(usuario_id)

    @staticmethod
    def listar_por_status(usuario_id, status="em_andamento"):
        return MetaRepository.listar_por_status(usuario_id, status=status)
