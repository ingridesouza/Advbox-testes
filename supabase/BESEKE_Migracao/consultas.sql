-- contagem total vs. ids únicos
select
  count(*) as total_linhas,
  count(distinct id) as ids_unicos
from djen_intimacoes;

-- (se existir algo aqui, tem duplicado – deveria retornar 0 linhas)
select id, count(*) as repeticoes
from djen_intimacoes
group by id
having count(*) > 1
order by repeticoes desc, id
limit 50;

-- Inserções por dia (últimos 14 dias) – valida o agendamento

select
  date_trunc('day', extraido_em) as dia,
  count(*) as qtd
from djen_intimacoes
where extraido_em >= now() - interval '14 days'
group by 1
order by 1 desc;


-- Distribuição por tribunal (últimos 7 dias)

select
  tribunal,
  count(*) as qtd
from djen_intimacoes
where data_publicacao >= now() - interval '7 days'
group by tribunal
order by qtd desc;


-- Amostra com “EDUARDO KOETZ” OU “RS73409” no texto
select id, tribunal, data_publicacao, left(texto, 160) as trecho
from djen_intimacoes
where texto ilike '%EDUARDO KOETZ%'
   or texto ilike '%RS73409%'
order by data_publicacao desc
limit 20;

-- Linhas que NÃO citam nem o nome nem a OAB 
select count(*) as possiveis_fora_do_escopo
from djen_intimacoes
where texto not ilike '%EDUARDO KOETZ%'
  and texto not ilike '%RS73409%';
