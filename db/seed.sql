insert into tenants (id, name) values
  ('tenant_demo', 'Bloom Cafe'),
  ('tenant_skate', 'Deckhouse Skate Shop')
  on conflict (id) do nothing;

insert into customers (id, tenant_id, name) values
  ('cust_a', 'tenant_demo', 'Returning Customer A'),
  ('cust_b', 'tenant_demo', 'New Customer B'),
  ('skate_a', 'tenant_skate', 'Returning Skater A'),
  ('skate_b', 'tenant_skate', 'New Skater B')
  on conflict (id) do nothing;

insert into customer_profile (tenant_id, customer_id, facts) values
  ('tenant_demo', 'cust_a', '{"name":"Linh","lactose_intolerant":true,"prefers":"oat milk lattes","last_order":"oat latte + almond croissant","memory_consent":"active"}'),
  ('tenant_skate', 'skate_a', '{"name":"Maya","preferred_deck_width":"8.25 inch","shoe_size":"US 8","last_order":"street deck + bearings","memory_consent":"active"}')
  on conflict (tenant_id, customer_id) do nothing;
-- Knowledge rows are inserted by the seed embeddings script because they need embeddings.
