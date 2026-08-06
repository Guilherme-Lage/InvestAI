-- ============================================================
-- InvestAI - Script de criação do banco de dados
-- Compatível com MySQL / MariaDB
-- ============================================================

CREATE DATABASE IF NOT EXISTS investai
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE investai;

-- ------------------------------------------------------------
-- Tabela: usuario
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuario (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    nome              VARCHAR(120)  NOT NULL,
    email             VARCHAR(120)  NOT NULL UNIQUE,
    perfil_risco      VARCHAR(20)   NOT NULL DEFAULT 'conservador',
    renda_mensal      DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    data_criacao      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- Tabela: movimentacao  (renda ou gasto do usuário)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS movimentacao (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    descricao         VARCHAR(120)  NOT NULL,
    tipo              VARCHAR(10)   NOT NULL,  -- 'renda' ou 'gasto'
    valor             DECIMAL(12,2) NOT NULL,
    data              VARCHAR(20)   NOT NULL,
    usuario_id        INT           NOT NULL,
    data_criacao      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_movimentacao_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuario (id)
        ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- Tabela: investimento
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS investimento (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    nome              VARCHAR(120)  NOT NULL,
    tipo              VARCHAR(40)   NOT NULL,  -- ex.: Tesouro Selic, CDB, LCI/LCA
    valor_aplicado    DECIMAL(12,2) NOT NULL,
    rendimento_atual  DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    liquidez          VARCHAR(40)   NOT NULL DEFAULT 'diaria',
    usuario_id        INT           NOT NULL,
    data_criacao      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_investimento_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuario (id)
        ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- Tabela: meta
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS meta (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    titulo            VARCHAR(120)  NOT NULL,
    valor_alvo        DECIMAL(12,2) NOT NULL,
    valor_atual       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    prazo             VARCHAR(20)   NOT NULL,
    usuario_id        INT           NOT NULL,
    data_criacao      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_meta_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuario (id)
        ON DELETE CASCADE
);
