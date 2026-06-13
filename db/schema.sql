create extension if not exists vector;

create table if not exists tenants (
  id text primary key,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists customers (
  id text primary key,
  tenant_id text not null references tenants(id),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists customer_profile (
  tenant_id text not null references tenants(id),
  customer_id text not null references customers(id),
  facts jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (tenant_id, customer_id)
);

create table if not exists knowledge (
  id bigint generated always as identity primary key,
  tenant_id text not null references tenants(id),
  title text not null,
  content text not null,
  embedding vector(1024) not null
);
create index if not exists knowledge_tenant_idx on knowledge(tenant_id);
create unique index if not exists knowledge_tenant_title_idx on knowledge(tenant_id, title);
create index if not exists knowledge_vec_idx on knowledge using ivfflat (embedding vector_cosine_ops) with (lists = 50);

create table if not exists handoffs (
  id bigint generated always as identity primary key,
  tenant_id text not null references tenants(id),
  customer_id text not null,
  reason text not null,
  created_at timestamptz not null default now(),
  status text not null default 'open'
);
