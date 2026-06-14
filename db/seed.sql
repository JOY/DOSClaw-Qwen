insert into tenants (id, name) values ('tenant_demo', 'Bloom Cafe')
  on conflict (id) do nothing;

insert into customers (id, tenant_id, name) values
  ('cust_a', 'tenant_demo', 'Returning Customer A'),
  ('cust_b', 'tenant_demo', 'New Customer B')
  on conflict (id) do nothing;

insert into customer_profile (tenant_id, customer_id, facts) values
  ('tenant_demo', 'cust_a', '{"name":"Linh","lactose_intolerant":true,"prefers":"oat milk lattes","last_order":"oat latte + almond croissant"}')
  on conflict (tenant_id, customer_id) do nothing;
-- Knowledge rows are inserted by the seed embeddings script because they need embeddings.
