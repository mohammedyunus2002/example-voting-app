# test_app.py

import pytest
from app import app as flask_app
from redis import Redis
from flask import Flask, jsonify


@pytest.fixture
def app():
    # Set up the Flask app for testing
    flask_app.config['TESTING'] = True
    yield flask_app


@pytest.fixture
def client(app):
    # Provide a test client for the Flask app
    return app.test_client()


@pytest.fixture
def redis_mock(monkeypatch):
    # Mock the Redis instance
    class MockRedis:
        def __init__(self):
            self.data = []

        def rpush(self, key, value):
            self.data.append(value)

        def lrange(self, key, start, end):
            return self.data

    monkeypatch.setattr(Redis, 'rpush', MockRedis().rpush)
    monkeypatch.setattr(Redis, 'lrange', MockRedis().lrange)
    return MockRedis()
    

def test_hello(client, redis_mock):
    # Test GET request to "/" route
    response = client.get('/')
    assert response.status_code == 200
    assert b'Cats' in response.data  # Ensure OPTION_A is in the response (default is "Cats")
    assert b'Dogs' in response.data  # Ensure OPTION_B is in the response (default is "Dogs")

    # Test POST request to "/" route
    data = {'vote': 'Cats'}
    response = client.post('/', data=data)
    assert response.status_code == 200
    assert b'Cats' in response.data
    assert len(redis_mock.data) > 0  # Ensure that vote was saved to the mock Redis
