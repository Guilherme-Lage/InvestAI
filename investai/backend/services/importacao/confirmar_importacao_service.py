from datetime import date

from sqlalchemy.exc import IntegrityError

from models import Movimentacao, TransacaoImportada, db
from repositories import TransacaoImportadaRepository

TIPOS_VALIDOS = ("renda", "gasto")
MAXIMO_POR_IMPORTACAO = 2000


class ConfirmarImportacaoService:
    """Segundo passo da importação: grava as transações que o usuário
    deixou marcadas na revisão, já com a categoria que ele escolheu.

    Cada uma vira uma Movimentacao comum (como se tivesse sido digitada,
    RF03/RF04) mais um registro em TransacaoImportada, que impede a mesma
    linha do extrato de entrar outra vez.
    """

    def executar(self, usuario_id, transacoes):
        if not isinstance(transacoes, list) or not transacoes:
            raise ValueError("Selecione ao menos uma transação para importar.")
        if len(transacoes) > MAXIMO_POR_IMPORTACAO:
            raise ValueError("Extrato grande demais. Importe um período menor.")

        # Valida tudo antes de gravar qualquer coisa: uma linha com problema
        # não pode deixar o extrato importado pela metade.
        validadas = [self._validar(transacao) for transacao in transacoes]

        ja_importadas = TransacaoImportadaRepository.identificadores_do_usuario(usuario_id)
        importadas = 0
        for transacao in validadas:
            if transacao["identificador"] in ja_importadas:
                continue  # toque duplo no botão, ou a mesma linha enviada duas vezes
            ja_importadas.add(transacao["identificador"])

            movimentacao = Movimentacao(
                descricao=transacao["descricao"],
                tipo=transacao["tipo"],
                valor=transacao["valor"],
                data=transacao["data"],
                categoria=transacao["categoria"],
                usuario_id=usuario_id,
            )
            db.session.add(movimentacao)
            db.session.flush()  # gera o id, ainda sem gravar de vez
            db.session.add(TransacaoImportada(
                identificador=transacao["identificador"],
                usuario_id=usuario_id,
                movimentacao_id=movimentacao.id,
            ))
            importadas += 1

        try:
            db.session.commit()  # um commit só: entra tudo ou não entra nada
        except IntegrityError:
            db.session.rollback()
            raise ValueError("Essa importação já estava em andamento. Tente de novo.")

        return {
            "importadas": importadas,
            "ja_existiam": len(validadas) - importadas,
        }

    def _validar(self, transacao):
        if not isinstance(transacao, dict):
            raise ValueError("Transação inválida.")

        identificador = str(transacao.get("identificador") or "").strip()
        descricao = str(transacao.get("descricao") or "").strip()
        if not identificador or not descricao:
            raise ValueError("Transação sem identificador ou sem descrição.")

        if transacao.get("tipo") not in TIPOS_VALIDOS:
            raise ValueError("O tipo deve ser 'renda' ou 'gasto'.")

        try:
            valor = float(transacao.get("valor"))
            data = date.fromisoformat(str(transacao.get("data")))
        except (TypeError, ValueError):
            raise ValueError(f"Valor ou data inválidos em \"{descricao}\".")
        if valor <= 0:
            raise ValueError(f"O valor de \"{descricao}\" deve ser maior que zero.")

        return {
            "identificador": identificador[:200],
            "descricao": descricao[:120],
            "tipo": transacao["tipo"],
            "valor": valor,
            "data": data.isoformat(),
            "categoria": str(transacao.get("categoria") or "outros").strip().lower(),
        }
