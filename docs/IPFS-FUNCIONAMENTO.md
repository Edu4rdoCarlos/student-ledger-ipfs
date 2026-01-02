# Como o IPFS Armazena Documentos

## Visão Geral

O IPFS (InterPlanetary File System) é um sistema de armazenamento distribuído que usa **content-addressing** - cada arquivo é identificado pelo hash do seu conteúdo, não pela sua localização.

## Conceitos Fundamentais

### Content-Addressing vs Location-Addressing

```
Location-Addressing (tradicional):
"Busque o arquivo em https://servidor.com/pasta/arquivo.pdf"
                     └─────────────┬─────────────────────┘
                              localização

Content-Addressing (IPFS):
"Busque o arquivo com hash QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco"
                          └─────────────────────┬─────────────────────────┘
                                         identidade do conteúdo
```

**Vantagem**: Se o conteúdo existir em qualquer lugar da rede, você consegue obtê-lo. O hash garante que é exatamente o arquivo esperado.

### CID (Content Identifier)

O CID é a "impressão digital" única de um arquivo:

```
Arquivo PDF                          CID
┌──────────────────┐                ┌─────────────────────────────────────────────┐
│ %PDF-1.4         │                │                                             │
│ ...conteúdo...   │ ──── hash ───▶ │ QmYwAPJzv5CZsnANOHXOPTGPGrFPhsSdFnNHZMPBVfRWBh │
│ %%EOF            │                │                                             │
└──────────────────┘                └─────────────────────────────────────────────┘

Se mudar 1 byte:                     CID completamente diferente
┌──────────────────┐                ┌─────────────────────────────────────────────┐
│ %PDF-1.4         │                │                                             │
│ ...conteúdo2..   │ ──── hash ───▶ │ QmT5NvUtoM5nWFfrQdVrFtvGfKFmG7AHE8P34isapyhCxX │
│ %%EOF            │                │                                             │
└──────────────────┘                └─────────────────────────────────────────────┘
```

### Formatos de CID

| Versão | Prefixo | Exemplo | Algoritmo |
|--------|---------|---------|-----------|
| CIDv0 | `Qm` | `QmYwAPJzv5CZsnA...` (46 chars) | SHA-256 + Base58 |
| CIDv1 | `bafy` | `bafybeigdyrzt5s...` (59+ chars) | SHA-256 + Base32 |

Ambos são equivalentes e podem ser convertidos entre si.

---

## Processo de Armazenamento

### Passo 1: Chunking (Divisão em Blocos)

Arquivos grandes são divididos em blocos menores (padrão: 256KB):

```
historico.pdf (1.5 MB)
┌─────────────────────────────────────────────────────────────┐
│                        Conteúdo do PDF                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ chunking
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ Bloco 1  │ │ Bloco 2  │ │ Bloco 3  │ │ Bloco 4  │ │ Bloco 5  │ │ Bloco 6  │
│  256KB   │ │  256KB   │ │  256KB   │ │  256KB   │ │  256KB   │ │  ~244KB  │
└──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘
     │            │            │            │            │            │
     ▼            ▼            ▼            ▼            ▼            ▼
   QmAbc...    QmDef...    QmGhi...    QmJkl...    QmMno...    QmPqr...
```

### Passo 2: Hashing de Cada Bloco

Cada bloco recebe seu próprio CID:

```
┌──────────────────────────────────────────────────────────────┐
│ Bloco 1 (bytes)                                              │
│ 0x25504446 2D312E34 0A312030 206F626A...                     │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼ SHA-256 + encoding
                    QmAbcdef123456789...
```

### Passo 3: Merkle DAG (Directed Acyclic Graph)

Os blocos são organizados em uma estrutura de árvore:

```
                    ┌─────────────────────┐
                    │     CID Raiz        │
                    │ QmRootXyz789...     │ ◄── Este é o CID retornado
                    │                     │
                    │ links: [            │
                    │   QmAbc...,         │
                    │   QmDef...,         │
                    │   QmGhi...,         │
                    │   ...               │
                    │ ]                   │
                    └──────────┬──────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           ▼                   ▼                   ▼
    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
    │   QmAbc...  │     │   QmDef...  │     │   QmGhi...  │
    │   Bloco 1   │     │   Bloco 2   │     │   Bloco 3   │
    │   (dados)   │     │   (dados)   │     │   (dados)   │
    └─────────────┘     └─────────────┘     └─────────────┘
```

### Passo 4: Armazenamento Local

Os blocos são salvos no datastore local:

```
./data/ipfs/
└── blocks/
    ├── AB/
    │   └── CIQABCDEF123.data    # Bloco 1
    ├── DE/
    │   └── CIQDEFGHI456.data    # Bloco 2
    └── ...
```

---

## Fluxo Completo no Student Ledger

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FLUXO DE UPLOAD                                    │
└─────────────────────────────────────────────────────────────────────────────┘

     Usuário              Backend API              IPFS Node           Hyperledger
        │                      │                      │                     │
        │  1. Upload PDF       │                      │                     │
        │  (multipart/form)    │                      │                     │
        │─────────────────────▶│                      │                     │
        │                      │                      │                     │
        │                      │  2. POST /api/v0/add │                     │
        │                      │  (envia bytes)       │                     │
        │                      │─────────────────────▶│                     │
        │                      │                      │                     │
        │                      │                      │ 3. Processa:        │
        │                      │                      │    - Chunking       │
        │                      │                      │    - Hashing        │
        │                      │                      │    - Merkle DAG     │
        │                      │                      │    - Salva blocos   │
        │                      │                      │                     │
        │                      │  4. Retorna CID      │                     │
        │                      │  {"Hash":"Qm..."}    │                     │
        │                      │◀─────────────────────│                     │
        │                      │                      │                     │
        │                      │  5. Registra documento                     │
        │                      │  (matrícula, tipo, CID, timestamp)         │
        │                      │─────────────────────────────────────────▶  │
        │                      │                      │                     │
        │                      │                      │      6. Valida CID  │
        │                      │                      │      Salva no ledger│
        │                      │                      │                     │
        │  7. Sucesso          │                      │                     │
        │  {cid, txId}         │                      │                     │
        │◀─────────────────────│                      │                     │
        │                      │                      │                     │


┌─────────────────────────────────────────────────────────────────────────────┐
│                           FLUXO DE DOWNLOAD                                  │
└─────────────────────────────────────────────────────────────────────────────┘

     Usuário              Backend API              IPFS Node           Hyperledger
        │                      │                      │                     │
        │  1. GET documento    │                      │                     │
        │  /docs/{matricula}   │                      │                     │
        │─────────────────────▶│                      │                     │
        │                      │                      │                     │
        │                      │  2. Busca CID do documento                 │
        │                      │─────────────────────────────────────────▶  │
        │                      │                      │                     │
        │                      │  3. Retorna CID      │                     │
        │                      │◀─────────────────────────────────────────  │
        │                      │                      │                     │
        │                      │  4. GET /ipfs/{CID}  │                     │
        │                      │─────────────────────▶│                     │
        │                      │                      │                     │
        │                      │                      │ 5. Reconstrói:      │
        │                      │                      │    - Lê Merkle DAG  │
        │                      │                      │    - Junta blocos   │
        │                      │                      │    - Retorna bytes  │
        │                      │                      │                     │
        │                      │  6. Retorna PDF      │                     │
        │                      │◀─────────────────────│                     │
        │                      │                      │                     │
        │  7. Stream PDF       │                      │                     │
        │◀─────────────────────│                      │                     │
        │                      │                      │                     │
```

---

## Verificação de Integridade

### Como garantir que o documento não foi alterado?

```
1. Documento original foi registrado com CID: QmABC123...

2. Anos depois, alguém questiona a autenticidade

3. Verificação:

   ┌─────────────────┐
   │ PDF recuperado  │
   │ do IPFS         │
   └────────┬────────┘
            │
            ▼ recalcula hash
   ┌─────────────────┐
   │ CID calculado:  │
   │ QmABC123...     │
   └────────┬────────┘
            │
            ▼ compara
   ┌─────────────────┐
   │ CID no ledger:  │
   │ QmABC123...     │
   └────────┬────────┘
            │
            ▼
   ┌─────────────────┐
   │   IGUAIS?       │
   │                 │
   │ SIM → Válido ✓  │
   │ NÃO → Adulterado ✗│
   └─────────────────┘
```

### Código de verificação

```typescript
async function verificarDocumento(cid: string): Promise<boolean> {
  // 1. Busca documento no IPFS
  const response = await fetch(`${IPFS_GATEWAY}/ipfs/${cid}`);
  const pdfBuffer = await response.arrayBuffer();

  // 2. Recalcula o CID do conteúdo baixado
  const calculatedCid = await calculateCID(pdfBuffer);

  // 3. Compara com o CID esperado
  return calculatedCid === cid;
}
```

---

## Deduplicação

O IPFS automaticamente deduplica conteúdo idêntico:

```
Aluno A envia: historico_2024.pdf ──▶ QmXyz789...
                                           │
                                           ▼
                                    ┌─────────────┐
                                    │ Armazenado  │
                                    │ 1x no disco │
                                    └─────────────┘
                                           ▲
                                           │
Aluno B envia: historico_2024.pdf ──▶ QmXyz789... (mesmo hash!)
(arquivo idêntico)

Resultado: Apenas 1 cópia armazenada, 2 referências
```

---

## Estrutura de Dados no Sistema

### No IPFS (./data/ipfs/)

```
data/ipfs/
├── blocks/           # Blocos de dados
│   ├── AA/
│   │   └── CIQ...data
│   ├── AB/
│   │   └── CIQ...data
│   └── ...
├── datastore/        # Índices e metadados
└── config            # Configuração do nó
```

### No Hyperledger (ledger)

```json
{
  "docType": "documento",
  "id": "DOC-2024-001",
  "matricula": "20241234",
  "tipo": "historico",
  "cid": "QmYwAPJzv5CZsnANOHXOPTGPGrFPhsSdFnNHZMPBVfRWBh",
  "timestamp": "2024-03-15T10:30:00Z",
  "hash": "sha256:abc123...",
  "registradoPor": "secretaria"
}
```

**Observação**: O Hyperledger armazena apenas metadados (~500 bytes), não o arquivo PDF (que pode ter vários MB).

---

## Comparação de Tamanhos

| Item | Tamanho Típico |
|------|----------------|
| PDF de histórico escolar | 500 KB - 2 MB |
| CID (referência) | 46-59 bytes |
| Registro no Hyperledger | ~500 bytes |

Para 10.000 documentos:
- **Armazenado no IPFS**: ~10 GB (PDFs reais)
- **Armazenado no Hyperledger**: ~5 MB (apenas CIDs e metadados)

---

## Vantagens desta Arquitetura

| Característica | Benefício |
|----------------|-----------|
| **Imutabilidade** | CID muda se conteúdo mudar - impossível adulterar sem detecção |
| **Verificabilidade** | Qualquer um pode verificar autenticidade recalculando o hash |
| **Eficiência** | Blockchain leve (só metadados), storage pesado separado |
| **Deduplicação** | Arquivos idênticos ocupam espaço uma única vez |
| **Descentralização** | IPFS pode ser distribuído em múltiplos nós |
| **Persistência** | Dados sobrevivem enquanto pelo menos 1 nó tiver cópia |

---

## Referências

- [IPFS Documentation](https://docs.ipfs.tech/)
- [Content Addressing](https://docs.ipfs.tech/concepts/content-addressing/)
- [Merkle DAG](https://docs.ipfs.tech/concepts/merkle-dag/)
- [CID Specification](https://github.com/multiformats/cid)
