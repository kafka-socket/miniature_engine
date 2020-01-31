![Erlang CI](https://github.com/kafka-socket/miniature_engine/workflows/Erlang%20CI/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/kafka-socket/miniature_engine/badge.svg?branch=master)](https://coveralls.io/github/kafka-socket/miniature_engine?branch=master)
[![codecov](https://codecov.io/gh/kafka-socket/miniature_engine/branch/master/graph/badge.svg)](https://codecov.io/gh/kafka-socket/miniature_engine)



# Miniature engine

Kafka to websocket transparent bidirectional bridge

## Run

```bash
export KAFKA_ADVERTISED_HOST_NAME=`ipconfig getifaddr en0`
docker-compse up -d
```

## Development

### Prerequisite

- Erlang 21
- rebar3

### Start external deps

`docker-compose up -d zk kafka`

### Run erlang console

`rebar3 shell`
