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
