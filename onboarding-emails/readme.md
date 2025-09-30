# Atividade 1 – Automação de Onboarding com n8n, Gmail e Supabase

## Descrição do fluxo

Este workflow implementa um processo de **onboarding automático de clientes**:

* O cliente é registrado no banco de dados (Supabase/Postgres).
* O sistema identifica qual conteúdo deve ser enviado (contexto X, Y ou Z).
* O n8n envia um e-mail personalizado via Gmail contendo links de **vídeo** e **PDF** referentes ao contexto.
* Cada envio é **registrado em log** no banco, e o status da fila é atualizado para indicar sucesso ou erro.

Fluxo resumido:

1. **Schedule Trigger** – executa o fluxo periodicamente (ex.: a cada 5 minutos).
2. **Postgres (Select pendentes)** – consulta a tabela `fila_envio` para buscar os clientes com status `pendente`.
3. **Split In Batches** – processa os envios um a um, evitando ultrapassar limites do Gmail.
4. **Gmail (Send message)** – envia o e-mail com links dinâmicos do PDF e vídeo.
5. **If** – verifica se o envio foi bem-sucedido.

   * **Ramo TRUE**: insere log de sucesso em `log_envios` e atualiza `fila_envio` para `enviado`.
   * **Ramo FALSE**: insere log de erro em `log_envios` e atualiza `fila_envio` para `erro`.

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


ALTER TABLE conteudos
ADD CONSTRAINT conteudos_contexto_unique UNIQUE (contexto);

```

---

## ▶️ Como executar o fluxo

1. **Importar o workflow**

   * Abra o n8n → *Import Workflow* → selecione o JSON fornecido.

2. **Criar credenciais**

   * **Postgres (Supabase):** insira host, porta (6543 se usar pooler), database, user e senha. Marque SSL.
   * **Gmail OAuth2:** crie um projeto no Google Cloud, habilite a Gmail API e configure credenciais OAuth2.

     * Escopo necessário: `https://www.googleapis.com/auth/gmail.send`
     * Redirect URI: `http://localhost:5678/rest/oauth2-credential/callback`

3. **Popular o banco com dados de teste**

   ```sql
   INSERT INTO conteudos (contexto, video_url, pdf_url) VALUES
   ('X', 'https://meu-video-x.com', 'https://meu-pdf-x.com'),
   ('Y', 'https://meu-video-y.com', 'https://meu-pdf-y.com'),
   ('Z', 'https://meu-video-z.com', 'https://meu-pdf-z.com')
   ON CONFLICT (contexto) DO NOTHING;

   INSERT INTO clientes (nome, email, contexto) VALUES
   ('Cliente X', 'cliente.x@teste.com', 'X'),
   ('Cliente Y', 'cliente.y@teste.com', 'Y'),
   ('Cliente Z', 'cliente.z@teste.com', 'Z')
   ON CONFLICT (email) DO NOTHING;

   INSERT INTO fila_envio (cliente_id, contexto)
   SELECT id, contexto FROM clientes;
   ```

4. **Executar o fluxo manualmente**

   * Clique em *Execute Workflow* no n8n.
   * O Gmail enviará os e-mails configurados.

5. **Agendar o fluxo**

   * Configure o *Schedule Trigger* (ex.: a cada 5 minutos) para rodar automaticamente.

---

## 🧪 Estratégia de testes

* **Teste de envio**: insira clientes fictícios na `fila_envio` e verifique se o e-mail chega.
* **Teste de duplicação**: rode o fluxo duas vezes seguidas e confira que o status `enviado` evita reenvio.
* **Teste de erro**: use um e-mail inválido, valide se cai no ramo `false` e se o status vira `erro`.


---

## ✅ O que foi entregue

* Workflow do n8n em JSON.
* Script SQL para criação das tabelas.
* Script de seed para popular dados de teste.
* README.md (este documento).
