-- catálogos
INSERT INTO conteudos (contexto, video_url, pdf_url, ativo) VALUES
('X','https://example.com/videos/onboarding-x.mp4','https://example.com/pdfs/onboarding-x.pdf', true),
('Y','https://example.com/videos/onboarding-y.mp4','https://example.com/pdfs/onboarding-y.pdf', true),
('Z','https://example.com/videos/onboarding-z.mp4','https://example.com/pdfs/onboarding-z.pdf', true)
ON CONFLICT (contexto) DO UPDATE
SET video_url = EXCLUDED.video_url,
    pdf_url   = EXCLUDED.pdf_url,
    ativo     = EXCLUDED.ativo;

-- clientes (pressupõe clientes.email UNIQUE; se não tiver, avise que eu ajusto)
INSERT INTO clientes (nome, email) VALUES
('Cliente X','ingridesouza040+onbx@gmail.com'),
('Cliente Y','ingridesouza040+onby@gmail.com'),
('Cliente Z','ingridesouza040+onbz@gmail.com'),
('Ingride Souza','ingridesouza040@gmail.com')
ON CONFLICT (email) DO UPDATE SET nome = EXCLUDED.nome;

-- fila (evita duplicar pendentes do mesmo cliente/contexto)
INSERT INTO fila_envio (cliente_id, contexto, status)
SELECT c.id, v.contexto, 'pendente'
FROM (
  VALUES
    ('ingridesouza040+onbx@gmail.com','X'),
    ('ingridesouza040+onby@gmail.com','Y'),
    ('ingridesouza040+onbz@gmail.com','Z'),
    ('ingridesouza040@gmail.com','Y')
) AS v(email, contexto)
JOIN clientes c ON c.email = v.email
WHERE NOT EXISTS (
  SELECT 1 FROM fila_envio f
  WHERE f.cliente_id = c.id
    AND f.contexto = v.contexto
    AND f.status = 'pendente'
);
