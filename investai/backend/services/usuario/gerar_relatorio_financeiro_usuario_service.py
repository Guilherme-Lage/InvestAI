from repositories import UsuarioRepository


class GerarRelatorioFinanceiroUsuarioService:
    """Relatório financeiro consolidado do usuário: saldo (rendas - gastos),
    total investido, rendimento total e progresso das metas."""

    def executar(self, usuario_id):
        return UsuarioRepository.relatorio_financeiro(usuario_id)
