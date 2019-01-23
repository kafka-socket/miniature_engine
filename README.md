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
