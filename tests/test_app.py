from app import app


def test_health():
    client = app.test_client()
    resp = client.get('/health')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data['status'] == 'healthy'


def test_set_failure_mode():
    client = app.test_client()
    resp = client.post('/failure', json={'enabled': True, 'error_rate': 0.0})
    assert resp.status_code == 200
    data = resp.get_json()
    assert data['failure_mode']['enabled'] is True
