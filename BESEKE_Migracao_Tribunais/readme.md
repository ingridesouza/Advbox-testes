# ADVBOX • Migração • E-mail Condicional (IA) — **Teste 3**

Este README documenta o fluxo do **n8n** que recebe um payload via **Webhook**, extrai os campos com **IA** (OpenAI-compat), aplica **regras condicionais por UF/sistema** e envia um **e-mail HTML** ao cliente com instruções personalizadas.

---

## Visão geral

* **Entrada:** JSON de webhook com dados do cliente/conta/“Dados do processo”.
* **Extração de campos:** HTTP Request para um provedor OpenAI-compat (usamos **DeepSeek** neste teste).
* **Fallback:** Regex robusto caso a IA falhe.
* **Pós-processamento:** Normalização + blocos condicionais (UF/sistemas).
* **Saída:** E-mail HTML (Gmail node) com assunto, destinatário e conteúdo formatado.

---

## Arquitetura do workflow (nós do n8n)

1. **Webhook**
   `POST /webhook-test/advbox/migracao/email` (modo teste)
   `POST /webhook/advbox/migracao/email` (produção)

2. **sanitize_input** *(Function)*

   * Extrai e normaliza: `raw`, `notes`, `cliente_nome`, `cliente_email`, `id_conta`, `responsible_nome`, `usersAdvbox`.

3. **Code in JavaScript** *(opcional utilitário)*

4. **extract_fields_gemini** *(HTTP Request)*

   * **URL:** `https://api.deepseek.com/chat/completions`
   * **Headers:**
     `Content-Type: application/json`
     `Authorization: Bearer sk-...`
   * **Body (Expression):** monta prompt e injeta `JSON.stringify($json)` como **PAYLOAD**.

5. **llm_http_guard** *(Function)*

   * Marca `__llm_fail` quando a chamada HTTP retorna erro.

6. **parse_gemini_json** *(Function)*

   * Lê JSON de retorno OpenAI-compat (choices/message/content ou tool_calls).
   * Se falhar, repassa contexto e sinaliza `__llm_fail: true`.

7. **IF llm_failed**

   * **true →** `regex_fallback`
   * **false →** `pass_llm`

8. **regex_fallback** *(Function)*

   * Extrai `plano`, `tipo_migracao`, `migrar`, `estados`, `id_conta`, `cliente_nome`, `responsible_nome/email` a partir de `notes`.

9. **normalize_rules** *(Function)*

   * Normaliza UFs, detecta sistemas (INSS/SEEU/PROJUDI/PJE/EPROC/CRETA), `busca_nacional`, conta estados.

10. **build_conditionals** *(Function)*

    * Gera textos condicionais por **UF** e por **sistema** → `ufBlocks`, `sysBlocks`.

11. **build_html_email** *(Function)*

    * Monta **assunto**, **destinatário** e **HTML** final (com as 3 partes e condicionais).

12. **Send a message (Gmail)**

    * Usa `{{$json.to}}`, `{{$json.subject}}`, `{{$json.html}}`.

13. **Respond to Webhook**

    * Retorna JSON com resumo (ex.: subject, to, tamanho do HTML).



---

## Provedor de IA 

**DeepSeek (OpenAI-compat)**

* **Endpoint:** `POST https://api.deepseek.com/chat/completions`
* **Header:** `Authorization: Bearer sk-SEU_TOKEN`
* **Body (exemplo):**

  ```json
  {
    "model": "deepseek-chat",
    "temperature": 0,
    "max_tokens": 1200,
    "messages": [
      {"role":"system","content":"Você é um extrator de campos. Responda APENAS com JSON válido."},
      {"role":"user","content":"Extraia os campos do payload... \n\nPAYLOAD:\n<JSON aqui>"}
    ]
  }
  ```
* O **Body** é montado no node via **Expression** com `JSON.stringify($json)` (o payload de entrada).

> 💡 Também funcionaria com o endpoint OpenAI-compat do Gemini, porém durante o teste a minha chave gerou `API_KEY_INVALID` e migrei para DeepSeek.

---

## Variáveis de ambiente

Você pode salvar a chave como variável de ambiente do Windows e referenciar no header:

* **Windows (permanente):**

  ```cmd
  setx DEEPSEEK_API_KEY "sk-xxxxxxxx"
  ```

  Reinicie o terminal e o n8n.

* **n8n Header (Expression):**

  ```js
  'Bearer ' + $env.DEEPSEEK_API_KEY
  ```

  > Se não quiser usar env var, cole o valor **inteiro** no header: `Bearer sk-...`

---

## Como executar local

1. Inicie o n8n:

   ```cmd
   n8n
   ```
2. Abra o workflow **ADVBOX • Migração • E-mail Condicional (IA)** e clique em **Execute workflow** (modo teste).
3. Em outro terminal, envie a **requisição de teste** abaixo.

### Requisição de teste

```cmd
curl -sS -X POST "http://localhost:5678/webhook-test/advbox/migracao/email" -H "Content-Type: application/json" -d "{\"id_conta\":\"81257\",\"nome_cliente\":\"BESEKE ADVOCACIA\",\"cliente_email\":\"anderson@beseke.adv.br\",\"Dados de usuários ADVBOX\":[{\"id\":1,\"users\":[{\"id\":47753,\"name\":\"ARTHUR SANTOS\",\"email\":\"AGATA.SANTOS@ADVBOX.COM.BR\"},{\"id\":5395,\"name\":\"ALAN VITAL\",\"email\":\"ALAN.VITAL@ADVBOX.COM.BR\"}]}],\"Dados do processo\":[{\"protocol_number\":\"81257\",\"type\":\"MIGRAÇÃO POR TRIBUNAIS\",\"group\":\"BANCA JURIDICA\",\"responsible_id\":5395,\"responsible\":\"ALAN VITAL\",\"notes\":\"ID da conta: 81257\\nPlano: Banca Jurídica\\n---\\nMigração por: tribunais com validação\\nResponsável: Anderson Beseke\\nE-mail: anderson@beseke.adv.br\\n----\\nPessoas\\nProcessos\\n---\\nDiários: Maranhão, Santa Catarina, São Paulo.\\nIntimações eletrônicas: Diário Oficial e DJEN.\\nLink da proposta: https://f005.backblazeb2.com/file/Backup-AD/Propostas/proposta_final_id_81257.pdf\"}]}"
```

> Dica: no **modo produção**, ative o workflow (toggle **Active**) e troque a URL para
> `http://localhost:5678/webhook/advbox/migracao/email`

---

## Saída esperada

* **Assunto:** `Migração ADVBOX • Conta 81257 • BESEKE ADVOCACIA`
* **Para:** `anderson@beseke.adv.br` (resolvido automaticamente a partir do payload/notes)
* **HTML:**

  * Saudação com nome;
  * **Parte 1** (Plano, Tipo de migração, O que será migrado, UFs, checklist);
  * **Blocos condicionais** conforme UFs/sistemas (ex.: PR/BA/RS/CRETA/INSS/SEEU etc.);
  * **Parte 2** (sobre os dados);
  * **Parte 3** (passo a passo + link da proposta, quando encontrado em `notes`);
  * Assinatura com **responsável** e **e-mail**.

---

## 🛠️ Troubleshooting rápido

* **404** “webhook … not registered”
  → Clique **Execute workflow** (modo teste) **ou** ative o fluxo (produção).

* **422** “Failed to parse request body”
  → JSON inválido no `-d` do `curl` (escapamento de aspas/`\"`/`\n`). Use o exemplo acima.

* **401** “Authentication Fails (auth header …)”
  → Header **Authorization** incorreto. Formato: `Bearer sk-…`

* **Env var não aparece (`Bearer undefined`)**
  → Use `setx` e **reinicie** terminal + n8n; ou cole a chave diretamente.

* **Gmail rejeita**
  → Verifique que `to` está preenchido (node `build_html_email` faz *hard-stop* se vazio).

---

## Notas finais

* O fluxo é **idempotente**: se a IA não retornar JSON válido, o **regex_fallback** cobre os campos essenciais.
* O **assunto** e a **saudação** usam fallback para `customers[0].name` quando `cliente_nome` não vem no topo.
* O link da proposta é detectado automaticamente no campo `notes`.

