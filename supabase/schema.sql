-- ════════════════════════════════════════════════════════════════════════
-- PATRIMÔNIO — SCHEMA SUPABASE (PostgreSQL)
-- Execute este arquivo inteiro no SQL Editor do seu projeto Supabase
-- (Project → SQL Editor → New Query → cole tudo → Run)
-- ════════════════════════════════════════════════════════════════════════

-- ── EXTENSÕES ──────────────────────────────────────────────────────────
create extension if not exists "pgcrypto";

-- ── TABELAS ────────────────────────────────────────────────────────────

-- Categorias de ativos (ex: Renda Fixa, Cripto) com percentual-alvo
create table if not exists categories (
  id bigint generated always as identity primary key,
  name text not null unique,
  color text not null default '#c9a84c',
  target_percent numeric(5,2) not null default 0,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- Ativos / contas (Rico, Nubank, Sicredi, Binance, etc.)
create table if not exists assets (
  id bigint generated always as identity primary key,
  name text not null unique,
  category_id bigint references categories(id) on delete set null,
  active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- Snapshots mensais (um registro por mês)
create table if not exists snapshots (
  id bigint generated always as identity primary key,
  year int not null,
  month int not null check (month between 1 and 12),
  label text not null,
  snapshot_date date not null,
  created_at timestamptz not null default now(),
  unique (year, month)
);

-- Valor de cada ativo em cada snapshot mensal
create table if not exists snapshot_values (
  id bigint generated always as identity primary key,
  snapshot_id bigint not null references snapshots(id) on delete cascade,
  asset_id bigint not null references assets(id) on delete cascade,
  value numeric(14,2) not null default 0,
  unique (snapshot_id, asset_id)
);

-- Aportes mensais (1 por snapshot)
create table if not exists contributions (
  id bigint generated always as identity primary key,
  snapshot_id bigint not null references snapshots(id) on delete cascade,
  amount numeric(14,2) not null default 0,
  note text,
  created_at timestamptz not null default now(),
  unique (snapshot_id)
);

-- ── ÍNDICES ────────────────────────────────────────────────────────────
create index if not exists idx_snapshot_values_snapshot on snapshot_values(snapshot_id);
create index if not exists idx_snapshot_values_asset    on snapshot_values(asset_id);
create index if not exists idx_assets_category          on assets(category_id);
create index if not exists idx_snapshots_year_month     on snapshots(year, month);

-- ── ROW LEVEL SECURITY ────────────────────────────────────────────────
-- Leitura pública (o dashboard é visível sem login).
-- Escrita apenas para usuários autenticados (você, via login no /admin).

alter table categories       enable row level security;
alter table assets           enable row level security;
alter table snapshots        enable row level security;
alter table snapshot_values  enable row level security;
alter table contributions    enable row level security;

-- Leitura pública
create policy "public read categories"      on categories      for select using (true);
create policy "public read assets"          on assets          for select using (true);
create policy "public read snapshots"       on snapshots       for select using (true);
create policy "public read snapshot_values" on snapshot_values for select using (true);
create policy "public read contributions"   on contributions   for select using (true);

-- Escrita (insert/update/delete) somente autenticado
create policy "auth write categories"      on categories      for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth write assets"          on assets          for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth write snapshots"       on snapshots       for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth write snapshot_values" on snapshot_values for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth write contributions"   on contributions   for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ── REALTIME ──────────────────────────────────────────────────────────
-- Habilita atualização em tempo real para as tabelas que o dashboard escuta
alter publication supabase_realtime add table categories;
alter publication supabase_realtime add table assets;
alter publication supabase_realtime add table snapshots;
alter publication supabase_realtime add table snapshot_values;
alter publication supabase_realtime add table contributions;

-- ════════════════════════════════════════════════════════════════════════
-- DADOS INICIAIS (SEED) — histórico completo Fev/2022 → Abr/2026
-- ════════════════════════════════════════════════════════════════════════

-- 1) Categorias (4 categorias com percentuais-alvo de exemplo — ajuste no admin)
insert into categories (name, color, target_percent, sort_order) values
  ('Corretoras de Investimentos','#c9a84c',55,1),
  ('Bancos & Carteiras Digitais','#7c9eb2',30,2),
  ('Criptomoedas','#b8860b',10,3),
  ('Internacional','#8a7963',5,4)
on conflict (name) do nothing;

-- 2) Ativos (19 contas/ativos identificados no histórico)
--    "active=false" = ativos descontinuados (não aparecem no formulário de novo mês)
insert into assets (name, category_id, active, sort_order) values
  ('Mercado Pago', (select id from categories where name='Bancos & Carteiras Digitais'), false, 0),
  ('MercadoPago', (select id from categories where name='Bancos & Carteiras Digitais'), true, 1),
  ('Nubank', (select id from categories where name='Bancos & Carteiras Digitais'), true, 2),
  ('Pagbank', (select id from categories where name='Bancos & Carteiras Digitais'), false, 3),
  ('PicPay', (select id from categories where name='Bancos & Carteiras Digitais'), true, 4),
  ('PicPay + MercadoPago', (select id from categories where name='Bancos & Carteiras Digitais'), false, 5),
  ('Picpay', (select id from categories where name='Bancos & Carteiras Digitais'), false, 6),
  ('Picpay-Nu CC', (select id from categories where name='Bancos & Carteiras Digitais'), false, 7),
  ('Santander', (select id from categories where name='Bancos & Carteiras Digitais'), true, 8),
  ('Sicredi', (select id from categories where name='Bancos & Carteiras Digitais'), true, 9),
  ('Clear + Bitybank', (select id from categories where name='Corretoras de Investimentos'), false, 10),
  ('Clear + Bitybank + PagBank', (select id from categories where name='Corretoras de Investimentos'), true, 11),
  ('Genial', (select id from categories where name='Corretoras de Investimentos'), false, 12),
  ('Genial Investimentos', (select id from categories where name='Corretoras de Investimentos'), false, 13),
  ('Rico', (select id from categories where name='Corretoras de Investimentos'), true, 14),
  ('XP 300%', (select id from categories where name='Corretoras de Investimentos'), false, 15),
  ('XP investimentos', (select id from categories where name='Corretoras de Investimentos'), true, 16),
  ('Binance', (select id from categories where name='Criptomoedas'), true, 17),
  ('Nomad + Espécie', (select id from categories where name='Internacional'), true, 18)
on conflict (name) do nothing;

-- 3) Snapshots mensais (45 meses)
insert into snapshots (year, month, label, snapshot_date) values
  (2022,2,'Fev 2022','2022-02-21'),
  (2022,3,'Mar 2022','2022-03-26'),
  (2022,4,'Abr 2022','2022-04-25'),
  (2022,5,'Mai 2022','2022-05-10'),
  (2022,6,'Jun 2022','2022-06-27'),
  (2022,7,'Jul 2022','2022-07-27'),
  (2022,8,'Ago 2022','2022-08-10'),
  (2022,9,'Set 2022','2022-09-01'),
  (2022,10,'Out 2022','2022-10-07'),
  (2022,11,'Nov 2022','2022-11-05'),
  (2022,12,'Dez 2022','2022-12-20'),
  (2023,2,'Fev 2023','2023-02-27'),
  (2023,3,'Mar 2023','2023-03-22'),
  (2023,5,'Mai 2023','2023-05-23'),
  (2023,6,'Jun 2023','2023-06-28'),
  (2023,7,'Jul 2023','2023-07-28'),
  (2023,8,'Ago 2023','2023-08-31'),
  (2023,9,'Set 2023','2023-09-28'),
  (2023,10,'Out 2023','2023-10-30'),
  (2023,11,'Nov 2023','2023-11-12'),
  (2023,12,'Dez 2023','2023-12-25'),
  (2024,2,'Fev 2024','2024-02-26'),
  (2024,3,'Mar 2024','2024-03-28'),
  (2024,4,'Abr 2024','2024-04-24'),
  (2024,5,'Mai 2024','2024-05-28'),
  (2024,7,'Jul 2024','2024-07-27'),
  (2024,8,'Ago 2024','2024-08-31'),
  (2024,9,'Set 2024','2024-09-28'),
  (2024,10,'Out 2024','2024-10-29'),
  (2024,11,'Nov 2024','2024-11-28'),
  (2024,12,'Dez 2024','2024-12-28'),
  (2025,2,'Fev 2025','2025-02-28'),
  (2025,3,'Mar 2025','2025-03-28'),
  (2025,4,'Abr 2025','2025-04-28'),
  (2025,5,'Mai 2025','2025-05-28'),
  (2025,6,'Jun 2025','2025-06-28'),
  (2025,7,'Jul 2025','2025-07-28'),
  (2025,8,'Ago 2025','2025-08-28'),
  (2025,10,'Out 2025','2025-10-27'),
  (2025,11,'Nov 2025','2025-11-28'),
  (2025,12,'Dez 2025','2025-12-28'),
  (2026,1,'Jan 2026','2026-01-28'),
  (2026,2,'Fev 2026','2026-02-28'),
  (2026,3,'Mar 2026','2026-03-29'),
  (2026,4,'Abr 2026','2026-04-29')
on conflict (year, month) do nothing;

-- 4) Valores de cada ativo em cada snapshot (351 registros)
insert into snapshot_values (snapshot_id, asset_id, value)
select sn.id, a.id, v.value
from (values
  (2022,2,'Rico',17194.00),
  (2022,2,'XP 300%',5250.07),
  (2022,2,'Nubank',7000.00),
  (2022,2,'Picpay-Nu CC',7048.60),
  (2022,2,'Binance',4800.00),
  (2022,3,'Rico',17947.00),
  (2022,3,'Santander',16533.00),
  (2022,3,'Genial Investimentos',10000.00),
  (2022,3,'Nubank',2295.00),
  (2022,3,'Picpay-Nu CC',5347.00),
  (2022,3,'Binance',3954.00),
  (2022,4,'Rico',18946.86),
  (2022,4,'Santander',16657.94),
  (2022,4,'Genial',10443.55),
  (2022,4,'Nubank',2539.06),
  (2022,4,'Picpay-Nu CC',6245.16),
  (2022,4,'Binance',3334.46),
  (2022,5,'Rico',18691.00),
  (2022,5,'Santander',16743.00),
  (2022,5,'Genial',10567.00),
  (2022,5,'Nubank',4758.00),
  (2022,5,'Picpay-Nu CC',6695.00),
  (2022,5,'Binance',2634.00),
  (2022,6,'Rico',18689.59),
  (2022,6,'Santander',17735.93),
  (2022,6,'Nubank',17667.80),
  (2022,6,'Picpay-Nu CC',10159.90),
  (2022,6,'Binance',1758.50),
  (2022,7,'Rico',20689.59),
  (2022,7,'Santander',17735.93),
  (2022,7,'Nubank',17667.80),
  (2022,7,'Picpay-Nu CC',10159.90),
  (2022,7,'Binance',1758.50),
  (2022,8,'Rico',28924.77),
  (2022,8,'Nubank',13073.54),
  (2022,8,'Santander',23061.44),
  (2022,8,'Picpay-Nu CC',6285.95),
  (2022,8,'Binance',1987.15),
  (2022,9,'Rico',30830.90),
  (2022,9,'Nubank',15028.70),
  (2022,9,'Santander',24237.43),
  (2022,9,'Picpay-Nu CC',3673.80),
  (2022,9,'Binance',1667.48),
  (2022,10,'Rico',36306.82),
  (2022,10,'Nubank',18835.82),
  (2022,10,'Santander',15826.13),
  (2022,10,'Picpay-Nu CC',6192.64),
  (2022,10,'Binance',1635.00),
  (2022,11,'Rico',36494.47),
  (2022,11,'Nubank',18306.74),
  (2022,11,'Santander',15953.74),
  (2022,11,'Picpay-Nu CC',5661.52),
  (2022,11,'Binance',1669.18),
  (2022,11,'Sicredi',346.68),
  (2022,11,'Pagbank',1008.97),
  (2022,12,'Rico',30676.96),
  (2022,12,'Nubank',25650.00),
  (2022,12,'Santander',15127.90),
  (2022,12,'Picpay-Nu CC',5561.81),
  (2022,12,'Binance',1190.23),
  (2022,12,'Sicredi',1176.95),
  (2022,12,'Pagbank',1027.17),
  (2022,12,'XP investimentos',5108.67),
  (2023,2,'Rico',32826.92),
  (2023,2,'Nubank',40075.41),
  (2023,2,'Santander',4086.36),
  (2023,2,'Picpay-Nu CC',386.94),
  (2023,2,'Binance',1720.38),
  (2023,2,'Sicredi',10047.32),
  (2023,2,'Pagbank',1054.49),
  (2023,2,'XP investimentos',5216.87),
  (2023,3,'Rico',32821.23),
  (2023,3,'Nubank',39359.88),
  (2023,3,'Santander',4010.00),
  (2023,3,'Picpay-Nu CC',78.37),
  (2023,3,'Binance',1743.61),
  (2023,3,'Sicredi',21228.42),
  (2023,3,'Pagbank',1064.55),
  (2023,3,'XP investimentos',5306.71),
  (2023,5,'Rico',36541.96),
  (2023,5,'Nubank',37245.29),
  (2023,5,'Santander',4101.06),
  (2023,5,'Picpay-Nu CC',98.50),
  (2023,5,'Binance',1528.55),
  (2023,5,'Sicredi',25139.22),
  (2023,5,'Pagbank',1089.20),
  (2023,5,'XP investimentos',5365.94),
  (2023,6,'Rico',37065.70),
  (2023,6,'Nubank',38892.15),
  (2023,6,'Santander',4101.06),
  (2023,6,'Picpay-Nu CC',400.02),
  (2023,6,'Binance',1340.12),
  (2023,6,'Sicredi',28300.38),
  (2023,6,'Pagbank',1104.52),
  (2023,6,'XP investimentos',5431.16),
  (2023,7,'Rico',37660.87),
  (2023,7,'Nubank',40075.41),
  (2023,7,'Santander',4086.36),
  (2023,7,'Picpay-Nu CC',386.94),
  (2023,7,'Binance',1416.00),
  (2023,7,'Sicredi',30134.32),
  (2023,7,'Pagbank',1120.68),
  (2023,7,'XP investimentos',5493.46),
  (2023,8,'Rico',38265.19),
  (2023,8,'Nubank',40976.75),
  (2023,8,'Santander',4124.62),
  (2023,8,'Picpay-Nu CC',417.92),
  (2023,8,'Binance',1252.24),
  (2023,8,'Sicredi',31686.41),
  (2023,8,'Pagbank',1132.82),
  (2023,8,'XP investimentos',5530.96),
  (2023,9,'Rico',37841.02),
  (2023,9,'Nubank',38021.47),
  (2023,9,'Santander',4164.55),
  (2023,9,'Picpay-Nu CC',5000.00),
  (2023,9,'Binance',1252.24),
  (2023,9,'Sicredi',32000.00),
  (2023,9,'Pagbank',1143.79),
  (2023,9,'XP investimentos',5579.11),
  (2023,10,'Rico',37618.02),
  (2023,10,'Nubank',38386.07),
  (2023,10,'Santander',4274.02),
  (2023,10,'Picpay-Nu CC',1232.64),
  (2023,10,'Binance',1501.42),
  (2023,10,'Sicredi',32893.31),
  (2023,10,'Pagbank',1123.05),
  (2023,10,'XP investimentos',5619.68),
  (2023,11,'Rico',38265.19),
  (2023,11,'Nubank',38555.86),
  (2023,11,'Santander',4291.28),
  (2023,11,'Picpay-Nu CC',1923.44),
  (2023,11,'Binance',1730.08),
  (2023,11,'Sicredi',36717.06),
  (2023,11,'XP investimentos',5640.49),
  (2023,12,'Rico',43457.28),
  (2023,12,'Nubank',40055.83),
  (2023,12,'Santander',4952.68),
  (2023,12,'Picpay-Nu CC',906.90),
  (2023,12,'Binance',2153.48),
  (2023,12,'Sicredi',39460.78),
  (2023,12,'XP investimentos',5947.05),
  (2024,2,'Rico',46650.21),
  (2024,2,'Nubank',39493.89),
  (2024,2,'Santander',4834.83),
  (2024,2,'Picpay-Nu CC',434.00),
  (2024,2,'Binance',2650.00),
  (2024,2,'Sicredi',52697.00),
  (2024,2,'Pagbank',360.00),
  (2024,2,'XP investimentos',5808.94),
  (2024,3,'Rico',55165.22),
  (2024,3,'Nubank',40822.24),
  (2024,3,'Santander',4694.78),
  (2024,3,'Picpay-Nu CC',277.65),
  (2024,3,'Binance',4000.00),
  (2024,3,'Sicredi',47933.29),
  (2024,3,'Clear + Bitybank',379.07),
  (2024,3,'XP investimentos',5897.00),
  (2024,4,'Rico',55682.47),
  (2024,4,'Nubank',41074.18),
  (2024,4,'Santander',5297.06),
  (2024,4,'Picpay-Nu CC',112.91),
  (2024,4,'Binance',4016.38),
  (2024,4,'Sicredi',43143.95),
  (2024,4,'Clear + Bitybank',1393.87),
  (2024,4,'XP investimentos',8029.97),
  (2024,5,'Rico',59341.38),
  (2024,5,'Nubank',42288.61),
  (2024,5,'Santander',7131.46),
  (2024,5,'Picpay-Nu CC',1995.47),
  (2024,5,'Binance',4362.42),
  (2024,5,'Sicredi',44218.45),
  (2024,5,'Clear + Bitybank',422.92),
  (2024,5,'XP investimentos',8184.00),
  (2024,7,'Rico',68272.49),
  (2024,7,'Nubank',42374.03),
  (2024,7,'Santander',5348.72),
  (2024,7,'Picpay',3509.40),
  (2024,7,'Binance',4305.07),
  (2024,7,'Sicredi',50942.54),
  (2024,7,'Clear + Bitybank',430.00),
  (2024,7,'XP investimentos',8332.45),
  (2024,8,'Rico',73352.02),
  (2024,8,'Nubank',42675.07),
  (2024,8,'Santander',4703.58),
  (2024,8,'Picpay',4766.05),
  (2024,8,'Binance',3467.32),
  (2024,8,'Sicredi',50507.54),
  (2024,8,'Clear + Bitybank',437.30),
  (2024,8,'XP investimentos',8407.05),
  (2024,9,'Rico',72706.37),
  (2024,9,'Nubank',43396.14),
  (2024,9,'Santander',5828.76),
  (2024,9,'Picpay',4771.02),
  (2024,9,'Binance',3866.22),
  (2024,9,'Sicredi',50172.32),
  (2024,9,'Clear + Bitybank',429.27),
  (2024,9,'XP investimentos',10506.64),
  (2024,10,'Rico',73063.76),
  (2024,10,'Nubank',44051.25),
  (2024,10,'Santander',6707.48),
  (2024,10,'Picpay',4698.38),
  (2024,10,'Binance',4188.16),
  (2024,10,'Sicredi',51047.56),
  (2024,10,'Clear + Bitybank',971.85),
  (2024,10,'XP investimentos',10705.05),
  (2024,11,'Rico',75744.70),
  (2024,11,'Nubank',42842.50),
  (2024,11,'Santander',5273.37),
  (2024,11,'PicPay + MercadoPago',6308.87),
  (2024,11,'Binance',7226.71),
  (2024,11,'Sicredi',53936.90),
  (2024,11,'Clear + Bitybank + PagBank',1086.13),
  (2024,11,'XP investimentos',11657.40),
  (2024,12,'Rico',78618.20),
  (2024,12,'Nubank',43034.12),
  (2024,12,'Santander',11019.51),
  (2024,12,'PicPay + MercadoPago',7191.77),
  (2024,12,'Binance',5866.25),
  (2024,12,'Sicredi',62054.43),
  (2024,12,'Clear + Bitybank + PagBank',746.53),
  (2024,12,'XP investimentos',11776.04),
  (2025,2,'Rico',81041.44),
  (2025,2,'Nubank',8666.99),
  (2025,2,'Santander',6487.25),
  (2025,2,'PicPay + MercadoPago',8289.36),
  (2025,2,'Binance',3583.61),
  (2025,2,'Sicredi',109604.74),
  (2025,2,'Clear + Bitybank + PagBank',757.79),
  (2025,2,'XP investimentos',11385.00),
  (2025,3,'Rico',85171.51),
  (2025,3,'Nubank',8662.80),
  (2025,3,'Santander',9528.78),
  (2025,3,'Picpay-Nu CC',6416.34),
  (2025,3,'Binance',3463.00),
  (2025,3,'Sicredi',103619.21),
  (2025,3,'Mercado Pago',1017.58),
  (2025,3,'Clear + Bitybank + PagBank',762.77),
  (2025,3,'XP investimentos',11515.00),
  (2025,4,'Rico',91886.98),
  (2025,4,'Nubank',9739.67),
  (2025,4,'Santander',5969.59),
  (2025,4,'PicPay + MercadoPago',8765.11),
  (2025,4,'Binance',3709.91),
  (2025,4,'Sicredi',113629.70),
  (2025,4,'Clear + Bitybank + PagBank',769.56),
  (2025,4,'XP investimentos',11569.28),
  (2025,5,'Rico',97038.93),
  (2025,5,'Nubank',10667.96),
  (2025,5,'Santander',6249.89),
  (2025,5,'PicPay + MercadoPago',8945.96),
  (2025,5,'Binance',4100.05),
  (2025,5,'Sicredi',113965.59),
  (2025,5,'Clear + Bitybank + PagBank',775.78),
  (2025,5,'XP investimentos',12100.59),
  (2025,6,'Rico',100526.07),
  (2025,6,'Nubank',10810.16),
  (2025,6,'Santander',6838.21),
  (2025,6,'PicPay + MercadoPago',8307.89),
  (2025,6,'Binance',3397.41),
  (2025,6,'Sicredi',117234.29),
  (2025,6,'Clear + Bitybank + PagBank',783.33),
  (2025,6,'XP investimentos',12129.16),
  (2025,7,'Rico',101083.85),
  (2025,7,'Nubank',13067.33),
  (2025,7,'Santander',8305.77),
  (2025,7,'MercadoPago',3025.45),
  (2025,7,'PicPay',5879.58),
  (2025,7,'Binance',4792.34),
  (2025,7,'Sicredi',114715.19),
  (2025,7,'Clear + Bitybank + PagBank',2374.98),
  (2025,7,'XP investimentos',12501.35),
  (2025,8,'Rico',104151.61),
  (2025,8,'Nubank',13285.10),
  (2025,8,'Santander',6255.27),
  (2025,8,'MercadoPago',5308.89),
  (2025,8,'PicPay',6022.64),
  (2025,8,'Binance',4747.80),
  (2025,8,'Sicredi',115095.00),
  (2025,8,'Clear + Bitybank + PagBank',2401.38),
  (2025,8,'XP investimentos',12538.37),
  (2025,8,'Nomad + Espécie',12538.37),
  (2025,10,'Rico',108758.00),
  (2025,10,'Nubank',13569.60),
  (2025,10,'Santander',6512.77),
  (2025,10,'MercadoPago',7329.22),
  (2025,10,'PicPay',6278.76),
  (2025,10,'Binance',4276.61),
  (2025,10,'Sicredi',116735.00),
  (2025,10,'Clear + Bitybank + PagBank',2244.37),
  (2025,10,'Nomad + Espécie',4674.03),
  (2025,10,'XP investimentos',12692.73),
  (2025,11,'Rico',111593.86),
  (2025,11,'Nubank',14622.00),
  (2025,11,'Santander',6681.58),
  (2025,11,'MercadoPago',8963.58),
  (2025,11,'PicPay',6430.43),
  (2025,11,'Binance',3156.96),
  (2025,11,'Sicredi',118461.00),
  (2025,11,'Clear + Bitybank + PagBank',5792.80),
  (2025,11,'Nomad + Espécie',4661.16),
  (2025,11,'XP investimentos',12503.66),
  (2025,12,'Rico',115472.41),
  (2025,12,'Nubank',15688.39),
  (2025,12,'Santander',6005.59),
  (2025,12,'MercadoPago',13914.91),
  (2025,12,'PicPay',6483.46),
  (2025,12,'Binance',2937.25),
  (2025,12,'Sicredi',127849.53),
  (2025,12,'Clear + Bitybank + PagBank',4712.71),
  (2025,12,'Nomad + Espécie',4661.16),
  (2025,12,'XP investimentos',12574.20),
  (2026,1,'Rico',121350.34),
  (2026,1,'Nubank',16760.54),
  (2026,1,'Santander',5914.48),
  (2026,1,'MercadoPago',19276.50),
  (2026,1,'PicPay',551.11),
  (2026,1,'Binance',2764.14),
  (2026,1,'Sicredi',131335.17),
  (2026,1,'Clear + Bitybank + PagBank',4756.57),
  (2026,1,'Nomad + Espécie',6468.18),
  (2026,1,'XP investimentos',8135.16),
  (2026,2,'Rico',130684.17),
  (2026,2,'Nubank',17223.84),
  (2026,2,'Santander',5923.01),
  (2026,2,'MercadoPago',17094.85),
  (2026,2,'PicPay',404.97),
  (2026,2,'Binance',1875.80),
  (2026,2,'Sicredi',159001.60),
  (2026,2,'Clear + Bitybank + PagBank',4815.67),
  (2026,2,'Nomad + Espécie',7231.76),
  (2026,2,'XP investimentos',7404.23),
  (2026,3,'Rico',137508.55),
  (2026,3,'Nubank',17346.60),
  (2026,3,'Santander',5929.62),
  (2026,3,'MercadoPago',20310.56),
  (2026,3,'PicPay',404.23),
  (2026,3,'Binance',1942.46),
  (2026,3,'Sicredi',160041.55),
  (2026,3,'Clear + Bitybank + PagBank',4878.12),
  (2026,3,'Nomad + Espécie',8840.69),
  (2026,3,'XP investimentos',7512.95),
  (2026,4,'Rico',139390.03),
  (2026,4,'Nubank',18473.60),
  (2026,4,'Santander',5854.95),
  (2026,4,'MercadoPago',21025.50),
  (2026,4,'PicPay',405.00),
  (2026,4,'Binance',1950.20),
  (2026,4,'Sicredi',163898.00),
  (2026,4,'Clear + Bitybank + PagBank',4937.16),
  (2026,4,'Nomad + Espécie',8885.78),
  (2026,4,'XP investimentos',6396.63)
) as v(year, month, asset_name, value)
join snapshots sn on sn.year = v.year and sn.month = v.month
join assets a on a.name = v.asset_name
on conflict (snapshot_id, asset_id) do update set value = excluded.value;

-- ════════════════════════════════════════════════════════════════════════
-- FIM. Verifique os dados com:
--   select s.label, sum(sv.value) as total
--   from snapshots s join snapshot_values sv on sv.snapshot_id = s.id
--   group by s.id, s.label order by s.id;
-- ════════════════════════════════════════════════════════════════════════
