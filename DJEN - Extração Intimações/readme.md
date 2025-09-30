# Extração de dados do Diário de Justiça Eletrônico Nacional (DJEN)

Automação para buscar diariamente intimações de um advogado específico no **DJEN**, normalizar o conteúdo em texto legível e salvar em uma tabela no **Supabase**, com deduplicação e paginação automática.

---

## Objetivo

* Extrair intimações do advogado **Eduardo Koetz** diretamente da API DJEN.
* Converter o conteúdo em **texto puro** com quebras de linha.
* Inserir no **Supabase** com `timestamp` da extração.
* Evitar duplicações pelo campo **id**.
* Tratar **paginação** da API.
* Garantir estabilidade com **lotes e esperas**.

---

## Arquitetura da Solução

### Fluxo n8n

```mermaid
flowchart LR
    A[Schedule Trigger] --> B[Prep Datas (D-1 a D)]
    B --> C[DJEN - Consulta]
    C -->|Saída 1| D[Normalizar + Mapear]
    D --> E[Trim Payload]
    E --> F[Split in Batches]
    F --> G[Supabase Insert]
    G --> F
    C -->|Saída 2| H[Tem próxima página?]
    H -->|true| I[Wait 1s]
    I --> J[Próxima Página]
    J --> C
```

---

## Configuração

### 1. **Trigger**

* Tipo: **Cron**
* Horário sugerido: **06:15** (dados já disponíveis após 02:00).

### 2. **Prep Datas (Function Node)**

```js
const hoje = new Date();
const ontem = new Date();
ontem.setDate(hoje.getDate() - 1);

function format(d) {
  return d.toISOString().split("T")[0];
}

return [{
  json: {
    dataInicio: format(ontem),
    dataFim: format(hoje),
    pagina: 1,
    itensPorPagina: 50,
    meio: "DJEN"
  }
}];
```

### 3. **DJEN – Consulta (HTTP Node)**

* Método: **GET**
* URL: `https://comunicaapi.pje.jus.br/api/v1/comunicacao`
* Params:

  * `dataInicio={{$json.dataInicio}}`
  * `dataFim={{$json.dataFim}}`
  * `pagina={{$json.pagina}}`
  * `itensPorPagina={{$json.itensPorPagina}}`
  * `texto=EDUARDO KOETZ`

---

## Paginação

### **Tem próxima página? (IF Node)**

```js
{{$json.items.length}} === {{$json.itensPorPagina}}
```

### **Próxima Página (Function Node)**

```js
const base = $item(0).$node["Prep Datas (D-1 a D)"].json;
const paginaAtual = Number($json.pagina ?? 1);

const MAX_PAGINAS = 500;
if (paginaAtual + 1 > MAX_PAGINAS) {
  return [];
}

return [{
  json: {
    ...base,
    pagina: paginaAtual + 1
  }
}];
```

### **Wait Node**

* 1000 ms (1 segundo) → evita limite de taxa da API.

---

## Normalização do Texto

### **Normalizar + Mapear (Function Node)**

* Extrai os campos relevantes (`id`, `dataPublicacao`, `texto`).
* Remove HTML, preserva quebras de linha.

### **Trim Payload (Function Node)**

* Trunca textos muito longos.
* Reduz o campo `fonte`.

---

## Inserção no Supabase

### Criação da Tabela

```sql
create table if not exists djen_intimacoes (
  id text primary key,               
  processo_numero text,
  orgao text,
  tribunal text,
  data_publicacao timestamptz,
  texto text,                        
  fonte jsonb,                      
  extraido_em timestamptz not null default timezone('UTC', now())
);

 
```

### **Split in Batches**

* Batch size: **10**
* Loop até processar todos os lotes.

### **Supabase Insert (HTTP Node)**

* Método: **POST**
* URL: `{{supabase_url}}/rest/v1/djen_intimacoes`
* Headers:

  ```http
  Authorization: Bearer {{supabase_service_key}}
  apikey: {{supabase_service_key}}
  Content-Type: application/json
  Prefer: resolution=ignore-duplicates, return=minimal
  Accept: application/json
  ```
* Body (RAW → JSON):

  ```json
  {{ $items().map(i => i.json) }}
  ```

---

## Validação

### Queries no Supabase

```sql
-- Últimos registros
select * from djen_intimacoes order by extraido_em desc limit 10;

-- Verificar duplicatas
select count(*), count(distinct id) from djen_intimacoes;

-- Registros por dia
select data_publicacao, count(*) 
from djen_intimacoes
group by data_publicacao
order by data_publicacao desc;
```

### Teste rápido no Postman

* POST em `{{supabase_url}}/rest/v1/djen_intimacoes`
* Headers: iguais ao n8n.
* Body:

```json
[
  {
    "id": "teste-123",
    "texto": "Intimação de teste",
    "data_publicacao": "2025-09-29",
    "advogado": "Eduardo Koetz",
    "fonte": { "tribunal": "TJRS" }
  }
]
```

---

## Cuidados

* Usar **service_role key** (não a anon).
* Se ocorrer **502 Bad Gateway**, reduzir batch para 5 e aumentar Wait para 2s.
* API DJEN tem **rate limit** → sempre respeitar tempo de espera.

---

## Conclusão

Este fluxo garante que:

* As intimações são extraídas **diariamente**.
* O texto fica **legível** no Supabase.
* **Não há duplicatas**.
* Paginação cobre todos os resultados.
* Fluxo estável com lotes pequenos + tempo de espera.
