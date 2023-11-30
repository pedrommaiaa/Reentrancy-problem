# Ignore instructions clashing with directory names
.PHONY: test docs

# Include .env file and export its variables
-include .env

test:; forge test --fork-url $(RPC_URL) -vvv