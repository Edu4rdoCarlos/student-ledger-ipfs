# Student Ledger IPFS

Servidor IPFS dedicado para armazenamento de documentos PDF do sistema Student Ledger.

## Arquitetura

```
Backend API                         Hyperledger Fabric
┌─────────────────┐                 ┌─────────────────┐
│                 │                 │                 │
│  1. Recebe PDF  │                 │  Apenas recebe  │
│  2. Upload IPFS │───── CID ─────▶│  e valida CID   │
│  3. Envia CID   │                 │  (imutável)     │
│                 │                 │                 │
└────────┬────────┘                 └─────────────────┘
         │
         ▼
┌─────────────────┐
│   IPFS Node     │  ← Container Docker
│   (kubo)        │     porta 5001 (API) / 8080 (gateway)
└─────────────────┘
```

## Requisitos

- Docker
- Docker Compose

## Início Rápido

```bash
# Copiar configuração
cp .env.example .env

# Iniciar servidor IPFS
docker compose up -d

# Verificar status
docker compose ps

# Ver logs
docker compose logs -f ipfs
```

## Portas

| Porta | Descrição |
|-------|-----------|
| 5001  | API HTTP (usado pelo backend) |
| 8080  | Gateway HTTP (acesso público aos arquivos) |
| 4001  | Swarm P2P (comunicação entre nós) |

## Testar

```bash
# Verificar se está rodando
curl -X POST http://localhost:5001/api/v0/id

# Upload de arquivo de teste
curl -X POST -F file=@documento.pdf http://localhost:5001/api/v0/add

# Acessar arquivo via gateway
# http://localhost:8080/ipfs/<CID>
```

## Integração com Backend

Adicionar no `.env` do backend (student-ledger-api):

```bash
IPFS_API_URL=http://localhost:5001
IPFS_GATEWAY_URL=http://localhost:8080
```

## Persistência

Os dados são persistidos em `./data/ipfs/`. Para backup:

```bash
docker compose down
tar -czvf ipfs-backup.tar.gz data/
```

## Documentação Completa

Ver [docs/IPFS-SETUP.md](docs/IPFS-SETUP.md) para informações detalhadas sobre configuração e rede privada.
