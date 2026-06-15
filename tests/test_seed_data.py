from pathlib import Path


SEED_SQL = Path(__file__).resolve().parents[1] / "db" / "seed.sql"


def test_seed_data_includes_richer_customer_personas_for_each_demo_tenant():
    sql = SEED_SQL.read_text(encoding="utf-8")

    assert sql.count("'tenant_demo'") >= 5
    assert sql.count("'tenant_skate'") >= 5
    assert "Regular Customer C" in sql
    assert "Complaint Follow-up Customer D" in sql
    assert "Parent Buyer C" in sql
    assert "Park Regular D" in sql
