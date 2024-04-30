.PHONY: clean
clean:
	rm -Rf env

trlyCfg:
	./trly-cfg.sh

start-kms:
	docker compose --file ./kms/docker-compose.yml up -d

stop-kms:
	docker compose --file ./kms/docker-compose.yml down

start-nginx:
	docker compose --file ./nginx/docker-compose.yml up -d

stop-nginx:
	docker compose --file ./nginx/docker-compose.yml down


stop-all-nodes:
	./icon.sh stop_node
	./wasm.sh stop_node archway

restart-all-nodes:
	./icon.sh stop_node
	./wasm.sh stop_node archway

	./icon.sh start_node
	./wasm.sh start_node archway

setup-evm:
	./evm.sh deploy xcall AVALANCHE
	./evm.sh deploy connection AVALANCHE

setup-all:
	./icon.sh deploy xcall
	./icon.sh deploy connection

	./wasm.sh deploy xcall ARCHWAY
	./wasm.sh deploy connection ARCHWAY

	./cfg.sh

