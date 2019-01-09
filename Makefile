.PHONY: run docker kafka
.DEFAULT_GOAL := run

run:
	rebar3 shell

docker:
	KAFKA_ADVERTISED_HOST_NAME=`ipconfig getifaddr en0` docker-compose up -d

kafka:
	kafka-console-consumer.sh --bootstrap-server localhost:9092 --from-beginning --topic my-topic
