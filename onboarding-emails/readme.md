## Automação de Coleta e Armazenamento de Intimações do DJEN

## Descrição do fluxo

Este workflow coleta automaticamente as publicações de intimações do **DJEN** (Diário de Justiça Eletrônico Nacional), extrai os textos relevantes e registra os dados no banco **Supabase (Postgres)**.
O fluxo evita duplicações e garante que todas as intimações sejam armazenadas para consultas posteriores.

Fluxo geral:

1. **Schedule Trigger** – dispara diariamente (ex.: 07:00).
2. **HTTP Request (DJEN)** – faz a requisição para buscar as intimações publicadas.
3. **Function / Set Node** – processa a resposta, limpa HTML e transforma em JSON com os campos esperados.
4. **Postgres (Supabase)** – insere as intimações na tabela `djen_intimacoes`, ignorando registros já existentes (baseado em hash/identificador).
5. (Opcional) **Log** – registra quantos registros foram coletados no dia para monitoramento.

---

## Estrutura do banco (Supabase/Postgres)

```sql
-- Tabela de clientes
create table clientes (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  email text not null unique,
  created_at timestamp default now()
);

-- Catálogo de conteúdos (vídeo + pdf por contexto)
create table conteudos (
  id serial primary key,
  contexto text not null, -- X, Y, Z
  video_url text not null,
  pdf_url text not null,
  ativo boolean default true
);

-- Fila de envios (quem deve receber)
create table fila_envio (
  id serial primary key,
  cliente_id uuid references clientes(id),
  contexto text not null,
  status text default 'pendente',
  created_at timestamp default now()
);

-- Log de envios (auditoria)
create table log_envios (
  id serial primary key,
  cliente_id uuid references clientes(id),
  contexto text not null,
  enviado_em timestamp default now(),
  status text
);
```

---

## Como executar o fluxo

1. **Importar o workflow**

   * Abra o n8n → *Import workflow* → selecione o arquivo JSON da Atividade 2.

2. **Configurar credenciais**

   * **Postgres (Supabase):** usar o host, database, user e senha obtidos no painel do Supabase.
   * Não há credenciais externas adicionais, apenas a conexão com o Supabase.

3. **Rodar os testes**

   * Execute manualmente o workflow via botão *Execute workflow*.
   * Verifique no Supabase se os registros foram inseridos:

     ```sql
     SELECT * FROM djen_intimacoes ORDER BY publicado_em DESC LIMIT 10;
     ```

4. **Agendamento**

   * Configure o *Schedule Trigger* para rodar diariamente no horário desejado.

---

## Estratégia de testes

* **n8n:** usar *Execute step* no nó de requisição HTTP para validar se a resposta do DJEN está correta.
* **Função de parsing:** inspecionar se os dados JSON gerados têm os campos `processo`, `parte`, `advogado`, `texto`, `publicado_em`.
* **Banco:** rodar queries no SQL Editor do Supabase para verificar:

  ```sql
  SELECT COUNT(*) FROM djen_intimacoes;
  SELECT publicado_em, COUNT(*) FROM djen_intimacoes GROUP BY publicado_em;
  ```
* **Teste de duplicação:** rodar o fluxo duas vezes no mesmo dia e verificar que não há duplicatas (graças ao campo `hash` único).

---

## O que foi entregue

* Workflow do n8n em JSON.
* Script SQL para criação da tabela `djen_intimacoes`.
* README.md (este documento).
