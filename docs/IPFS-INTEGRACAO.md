# Integração IPFS - Student Ledger

## Visão Geral

O Student Ledger utiliza o IPFS (InterPlanetary File System) como camada de backup para documentos de TCC. O IPFS armazena os PDFs das atas de defesa, enquanto o Hyperledger Fabric armazena apenas o CID (Content Identifier) para verificação de autenticidade.

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────────┐
│   Backend   │────▶│    IPFS     │     │  Hyperledger Fabric │
│   (API)     │     │  (Arquivo)  │     │      (CID)          │
└─────────────┘     └─────────────┘     └─────────────────────┘
      │                   │                       │
      │  1. Upload PDF    │                       │
      │──────────────────▶│                       │
      │                   │                       │
      │  2. Retorna CID   │                       │
      │◀──────────────────│                       │
      │                   │                       │
      │  3. Registra CID no blockchain            │
      │──────────────────────────────────────────▶│
      │                   │                       │
```

## O que é IPFS?

IPFS é um sistema de arquivos distribuído que:

- **Endereçamento por Conteúdo**: Cada arquivo recebe um identificador único (CID) baseado no seu conteúdo
- **Imutabilidade**: O mesmo arquivo sempre gera o mesmo CID
- **Descentralização**: Arquivos podem ser armazenados em múltiplos nós
- **Persistência**: Com "pinning", arquivos permanecem disponíveis permanentemente

### Formatos de CID

O chaincode aceita dois formatos de CID:

| Formato | Prefixo | Exemplo | Comprimento |
|---------|---------|---------|-------------|
| CIDv0 | `Qm` | `QmYwAPJzv5CZsnANOHXOPTGPGrFPhsSdFnNHZMPBVfRWBh` | 46 caracteres |
| CIDv1 | `bafy` | `bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi` | 59+ caracteres |

## Arquitetura

### Componentes

1. **Backend API**: Gerencia upload para IPFS e comunicação com blockchain
2. **IPFS Node**: Armazena os arquivos PDF (pode ser local ou serviço como Pinata/Infura)
3. **Hyperledger Fabric**: Armazena o CID para verificação imutável

### Fluxo de Registro

```
1. Coordenador submete PDF da ata
2. Backend faz upload para IPFS
3. IPFS retorna CID do arquivo
4. Backend registra CID no blockchain (com aprovações)
5. Documento está protegido: PDF no IPFS, CID no blockchain
```

### Fluxo de Verificação

```
1. Usuário submete PDF para verificação
2. Backend calcula CID do PDF (sem fazer upload)
3. Backend consulta blockchain pelo CID
4. Se encontrado: documento autêntico
5. Se não encontrado: documento não registrado/alterado
```

### Fluxo de Recuperação

```
1. DB do backend é perdido/corrompido
2. Consultar blockchain pela matrícula → obtém CID
3. Usar CID para baixar PDF do IPFS
4. Documento recuperado com integridade garantida
```

## Instalação do IPFS

### Opção 1: IPFS Local (Desenvolvimento)

```bash
# macOS
brew install ipfs

# Linux
wget https://dist.ipfs.tech/kubo/v0.24.0/kubo_v0.24.0_linux-amd64.tar.gz
tar -xvzf kubo_v0.24.0_linux-amd64.tar.gz
cd kubo
sudo bash install.sh

# Inicializar
ipfs init
ipfs daemon
```

### Opção 2: Serviço de Pinning (Produção)

Recomendados para produção:

- **Pinata**: https://pinata.cloud (1GB grátis)
- **Infura IPFS**: https://infura.io/product/ipfs
- **Web3.Storage**: https://web3.storage (5GB grátis)

## Implementação no Backend

### Dependências

```bash
npm install ipfs-http-client
# ou para serviços de pinning
npm install @pinata/sdk
```

### Serviço IPFS

```typescript
// src/services/ipfs.service.ts
import { create } from 'ipfs-http-client';
import * as fs from 'fs';

export class IPFSService {
  private client;

  constructor() {
    // IPFS local
    this.client = create({ url: 'http://localhost:5001/api/v0' });

    // Ou Infura
    // this.client = create({
    //   host: 'ipfs.infura.io',
    //   port: 5001,
    //   protocol: 'https',
    //   headers: {
    //     authorization: 'Basic ' + Buffer.from(PROJECT_ID + ':' + PROJECT_SECRET).toString('base64')
    //   }
    // });
  }

  /**
   * Faz upload de arquivo para IPFS
   * @returns CID do arquivo
   */
  async uploadFile(filePath: string): Promise<string> {
    const fileContent = fs.readFileSync(filePath);
    const result = await this.client.add(fileContent, {
      pin: true  // Garante persistência
    });
    return result.cid.toString();
  }

  /**
   * Faz upload de buffer para IPFS
   */
  async uploadBuffer(buffer: Buffer): Promise<string> {
    const result = await this.client.add(buffer, { pin: true });
    return result.cid.toString();
  }

  /**
   * Calcula CID sem fazer upload (para verificação)
   */
  async calculateCID(buffer: Buffer): Promise<string> {
    const result = await this.client.add(buffer, {
      onlyHash: true  // Não faz upload, apenas calcula
    });
    return result.cid.toString();
  }

  /**
   * Baixa arquivo do IPFS
   */
  async downloadFile(cid: string): Promise<Buffer> {
    const chunks: Uint8Array[] = [];
    for await (const chunk of this.client.cat(cid)) {
      chunks.push(chunk);
    }
    return Buffer.concat(chunks);
  }

  /**
   * Verifica se arquivo existe no IPFS
   */
  async fileExists(cid: string): Promise<boolean> {
    try {
      const stat = await this.client.files.stat(`/ipfs/${cid}`);
      return stat.size > 0;
    } catch {
      return false;
    }
  }
}
```

### Integração com Blockchain

```typescript
// src/services/document.service.ts
import { IPFSService } from './ipfs.service';
import { FabricClient } from './fabric.client';

export class DocumentService {
  private ipfs = new IPFSService();
  private fabric = new FabricClient();

  /**
   * Registra documento no sistema
   */
  async registerDocument(pdfBuffer: Buffer, metadata: DocumentMetadata) {
    // 1. Upload para IPFS
    const ipfsCid = await this.ipfs.uploadBuffer(pdfBuffer);
    console.log(`PDF uploaded to IPFS: ${ipfsCid}`);

    // 2. Registrar no blockchain
    await this.fabric.connect('coordenacao');
    const contract = this.fabric.getContract('DocumentWriteContract');

    const result = await contract.submitTransaction(
      'registerDocument',
      ipfsCid,
      metadata.matricula,
      metadata.defenseDate,
      metadata.notaFinal.toString(),
      metadata.resultado,
      metadata.motivo,
      'APROVADO',
      JSON.stringify(metadata.signatures),
      new Date().toISOString()
    );

    await this.fabric.disconnect();
    return JSON.parse(result.toString());
  }

  /**
   * Verifica autenticidade de documento
   */
  async verifyDocument(pdfBuffer: Buffer): Promise<VerificationResult> {
    // 1. Calcular CID do PDF (sem upload)
    const calculatedCid = await this.ipfs.calculateCID(pdfBuffer);

    // 2. Buscar no blockchain
    await this.fabric.connect('coordenacao');
    const contract = this.fabric.getContract('DocumentQueryContract');

    const result = await contract.evaluateTransaction(
      'verifyDocument',
      calculatedCid
    );

    await this.fabric.disconnect();
    return JSON.parse(result.toString());
  }

  /**
   * Recupera documento do IPFS usando dados do blockchain
   */
  async recoverDocument(matricula: string): Promise<Buffer> {
    // 1. Buscar CID no blockchain
    await this.fabric.connect('coordenacao');
    const contract = this.fabric.getContract('DocumentQueryContract');

    const result = await contract.evaluateTransaction(
      'getLatestDocument',
      matricula
    );

    const document = JSON.parse(result.toString());
    await this.fabric.disconnect();

    // 2. Baixar do IPFS
    const pdfBuffer = await this.ipfs.downloadFile(document.ipfsCid);
    return pdfBuffer;
  }
}
```

## API REST

### Endpoints

```typescript
// POST /api/documents/upload
// Faz upload de documento e registra no blockchain
app.post('/api/documents/upload', upload.single('pdf'), async (req, res) => {
  const pdfBuffer = req.file.buffer;
  const metadata = req.body;

  const result = await documentService.registerDocument(pdfBuffer, metadata);
  res.json(result);
});

// POST /api/documents/verify
// Verifica autenticidade de documento
app.post('/api/documents/verify', upload.single('pdf'), async (req, res) => {
  const pdfBuffer = req.file.buffer;

  const result = await documentService.verifyDocument(pdfBuffer);
  res.json(result);
});

// GET /api/documents/recover/:matricula
// Recupera documento do IPFS
app.get('/api/documents/recover/:matricula', async (req, res) => {
  const { matricula } = req.params;

  const pdfBuffer = await documentService.recoverDocument(matricula);

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename=${matricula}.pdf`);
  res.send(pdfBuffer);
});
```

## Comandos IPFS Úteis

```bash
# Adicionar arquivo
ipfs add documento.pdf

# Baixar arquivo
ipfs cat QmXxx... > documento.pdf

# Ver arquivo no gateway público
# https://ipfs.io/ipfs/QmXxx...

# Listar pins locais
ipfs pin ls

# Adicionar pin (manter arquivo)
ipfs pin add QmXxx...

# Remover pin
ipfs pin rm QmXxx...

# Verificar conexões
ipfs swarm peers

# Status do daemon
ipfs id
```

## Validação de CID no Chaincode

O chaincode valida automaticamente o formato do CID:

```typescript
// CIDv0: Qm + 44 caracteres alfanuméricos
const cidV0Regex = /^Qm[a-zA-Z0-9]{44}$/;

// CIDv1: bafy + 55+ caracteres (base32)
const cidV1Regex = /^bafy[a-z2-7]{55,}$/;

if (!cidV0Regex.test(ipfsCid) && !cidV1Regex.test(ipfsCid)) {
  throw new Error('CID inválido');
}
```

## Considerações de Produção

### Persistência

- **Pinning**: Sempre use `pin: true` ao fazer upload
- **Múltiplos nós**: Configure replicação para redundância
- **Serviço de pinning**: Use Pinata/Infura para garantir disponibilidade

### Segurança

- IPFS é público por padrão - qualquer um com o CID pode acessar
- Para documentos sensíveis, considere criptografia antes do upload
- O CID no blockchain garante integridade, não confidencialidade

### Performance

- CIDs são determinísticos - cache é seguro
- Use gateway local para melhor performance
- Configure timeout adequado para operações de rede

### Backup

```bash
# Exportar todos os pins
ipfs pin ls -q > pins.txt

# Importar pins em outro nó
cat pins.txt | xargs -I {} ipfs pin add {}
```

## Troubleshooting

### IPFS daemon não conecta

```bash
# Verificar se daemon está rodando
ipfs id

# Reiniciar daemon
ipfs shutdown
ipfs daemon
```

### CID não encontrado

```bash
# Verificar se arquivo está pinado
ipfs pin ls | grep QmXxx

# Tentar recuperar de peers
ipfs dht findprovs QmXxx
```

### Timeout em upload

```typescript
// Aumentar timeout
const client = create({
  url: 'http://localhost:5001/api/v0',
  timeout: 60000  // 60 segundos
});
```

## Referências

- [IPFS Docs](https://docs.ipfs.tech/)
- [IPFS HTTP Client](https://github.com/ipfs/js-ipfs/tree/master/packages/ipfs-http-client)
- [Pinata SDK](https://docs.pinata.cloud/)
- [CID Specification](https://github.com/multiformats/cid)
