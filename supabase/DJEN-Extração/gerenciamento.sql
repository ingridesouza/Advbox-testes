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

 