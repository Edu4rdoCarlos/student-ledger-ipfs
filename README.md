# Academic Ledger IPFS

Cluster IPFS privado para armazenamento distribuído de documentos acadêmicos criptografados.

## Sobre

Este projeto é o módulo de armazenamento do sistema Academic Ledger. Armazena PDFs de documentos acadêmicos (diplomas, históricos, certificados) de forma distribuída e imutável.

**O que armazena:** Arquivos criptografados (AES-256-GCM) enviados pelo backend.

**Relacionado a:**
- [student-ledger-api](../student-ledger-api) - Backend que envia os arquivos
- [student-ledger](../student-ledger) - Rede Hyperledger Fabric

## Tecnologias

- **IPFS Kubo** - Armazenamento distribuído
- **Docker** - Containerização
- **mTLS** - Autenticação mútua entre backend e IPFS
- **Swarm Key** - Rede privada isolada

## Arquitetura

```
Backend (student-ledger-api)
        │
        │ mTLS (porta 5443)
        ▼
┌─────────────────────────────────┐
│  IPFS Orderer    ←──→  IPFS     │
│  (porta 5443)         Coordenação│
│                       (porta 5444)│
└─────────────────────────────────┘
        │
        │ Docker network (fabric-net)
        ▼
Hyperledger Fabric
```

## Uso

**Requisitos:** Docker, Docker Compose, rede `fabric-net` ativa

```bash
# Gerar certificados mTLS (copie a saída para os arquivos .env)
./scripts/generate-certs.sh

# Iniciar cluster
docker compose up -d

# Verificar status
docker compose ps

# Ver logs
docker compose logs -f
```

## Estrutura

```
├── docker-compose.yml      # Orquestração dos containers
├── Dockerfile.ipfs         # Imagem IPFS customizada
├── scripts/
│   ├── generate-certs.sh   # Gera certificados mTLS
│   └── start-ipfs.sh       # Script de inicialização
├── data/                   # Dados persistentes (não versionado)
├── swarm.key               # Chave da rede privada (não versionado)
└── .env                    # Certificados mTLS (não versionado)
```

## Portas

| Serviço | mTLS | Swarm P2P |
|---------|------|-----------|
| ipfs-orderer | 5443 | 4001 |
| ipfs-coordenacao | 5444 | 4002 |
