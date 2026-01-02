# Student Ledger IPFS - Guia de Configuração

## Visão Geral

Servidor IPFS dedicado para armazenamento de documentos PDF do sistema Student Ledger.

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│   Backend API                         Hyperledger Fabric         │
│   ┌─────────────────┐                 ┌─────────────────┐        │
│   │                 │                 │                 │        │
│   │  1. Recebe PDF  │                 │  Apenas recebe  │        │
│   │  2. Upload IPFS │───── CID ─────▶│  e valida CID   │        │
│   │  3. Envia CID   │                 │  (imutável)     │        │
│   │                 │                 │                 │        │
│   └────────┬────────┘                 └─────────────────┘        │
│            │                                                     │
│            ▼                                                     │
│   ┌─────────────────┐                                            │
│   │   IPFS Node     │  ← Container Docker separado               │
│   │   (kubo)        │     porta 5001 (API) / 8080 (gateway)      │
│   └─────────────────┘                                            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Estrutura do Projeto

```
student-ledger-ipfs/
├── docker-compose.yml
├── .env
├── .env.example
├── .gitignore
├── README.md
└── data/                 # Volume IPFS (gitignore)
    └── .gitkeep
```

## Arquivos

### docker-compose.yml

```yaml
services:
  ipfs:
    image: ipfs/kubo:latest
    container_name: student-ledger-ipfs
    restart: unless-stopped
    ports:
      # API HTTP - usado pelo backend
      - "5001:5001"
      # Gateway HTTP - acesso público aos arquivos
      - "8080:8080"
      # Swarm - comunicação P2P (opcional para rede privada)
      - "4001:4001"
    volumes:
      - ./data/ipfs:/data/ipfs
    environment:
      - IPFS_PROFILE=server
    healthcheck:
      test: ["CMD", "ipfs", "id"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### .env.example

```bash
# IPFS Configuration
IPFS_API_PORT=5001
IPFS_GATEWAY_PORT=8080
IPFS_SWARM_PORT=4001
```

### .gitignore

```
# IPFS data
data/ipfs/

# Environment
.env

# OS
.DS_Store
```

## Comandos

### Iniciar o servidor IPFS

```bash
cd student-ledger-ipfs
docker compose up -d
```

### Verificar status

```bash
docker compose ps
docker compose logs -f ipfs
```

### Testar API

```bash
# Verificar se está rodando
curl -X POST http://localhost:5001/api/v0/id

# Upload de arquivo de teste
curl -X POST -F file=@documento.pdf http://localhost:5001/api/v0/add

# Resposta esperada:
# {"Name":"documento.pdf","Hash":"QmXxx...","Size":"12345"}
```

### Acessar arquivo via gateway

```
http://localhost:8080/ipfs/QmXxx...
```

## Integração com Backend

### Variáveis de ambiente no backend (student-ledger-api/.env)

```bash
# IPFS
IPFS_API_URL=http://localhost:5001
IPFS_GATEWAY_URL=http://localhost:8080
```

### Exemplo de uso no backend

```typescript
// Upload de arquivo
const formData = new FormData();
formData.append('file', pdfBuffer, 'documento.pdf');

const response = await fetch(`${IPFS_API_URL}/api/v0/add`, {
  method: 'POST',
  body: formData,
});

const { Hash: cid } = await response.json();
// cid = "QmXxx..." ou "bafyxxx..."

// Enviar CID para o Hyperledger
await fabricService.registerDocument(user, cid, matricula, ...);
```

## Formato do CID

O IPFS retorna CIDs em dois formatos:

| Versão | Formato | Exemplo |
|--------|---------|---------|
| CIDv0 | `Qm` + 44 chars | `QmYwAPJzv5CZsnANOHXOPTGPGrFPhsSdFnNHZMPBVfRWBh` |
| CIDv1 | `bafy` + 55+ chars | `bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi` |

O chaincode do Hyperledger aceita ambos os formatos.

## Persistência

Os dados do IPFS são persistidos em `./data/ipfs/`. Para backup:

```bash
# Parar container
docker compose down

# Backup do diretório data
tar -czvf ipfs-backup.tar.gz data/

# Restaurar
tar -xzvf ipfs-backup.tar.gz
docker compose up -d
```

## Rede Privada (Opcional)

Para criar uma rede IPFS privada (isolada da rede pública):

1. Gerar swarm key:
```bash
echo -e "/key/swarm/psk/1.0.0/\n/base16/\n$(tr -dc 'a-f0-9' < /dev/urandom | head -c64)" > swarm.key
```

2. Adicionar ao docker-compose.yml:
```yaml
volumes:
  - ./data/ipfs:/data/ipfs
  - ./swarm.key:/data/ipfs/swarm.key
environment:
  - LIBP2P_FORCE_PNET=1
```

## Próximos Passos

1. Criar o projeto `student-ledger-ipfs`
2. Configurar docker-compose.yml
3. Criar módulo IPFS no backend (`src/modules/ipfs/`)
4. Integrar upload de PDF com registro no Hyperledger
