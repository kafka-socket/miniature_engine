.PHONY: run docker kafka kafkap
.DEFAULT_GOAL := run

run:
	rebar3 shell

docker:
	KAFKA_ADVERTISED_HOST_NAME=`ipconfig getifaddr en0` docker-compose up -d

kafka:
	kafka-console-consumer.sh --bootstrap-server localhost:9092 --from-beginning --topic my-topic

kafkap:
	kafka-console-producer.sh \
		--broker-list localhost:9092 \
		--topic their-topic \
		--property "parse.key=true" \
		--property "key.separator=:"
