# Makefile for Forge (Foundry) commands

# Compile contracts
build: 
	@forge build

# Run tests
test:
	@forge test -vv

# Run a specific test file
test-file:
	@forge test --match-path test/<filename>.t.sol -vv

# Deploy contract using a script
deploy:
@forgeScriptScript/Deploy.s.sol:DeployBroadcastRpcUrl$(RPCURL)PrivateKey$(PRIVATEKEY)
# Run scripts locally without broadcasting
run:
	@forge script script/Deploy.s.sol:Deploy --rpc-url $(RPC_URL)

# Format code using forge-fmt
fmt:
	@forge fmt

# Clean artifacts and cache
clean:
	@forge clean

# Generate gas report
gas:
	@forge test --gas-report

# Set environment variables and run tests
test-env:
	@FOUNDRY_PROFILE=ci forge test -vv

# Help
help:
	@echo "Makefile commands:"
	@echo "  build       - Compile contracts"
	@echo "  test        - Run tests"
	@echo "  test-file   - Run a specific test file"
	@echo "  deploy      - Deploy contract using a script (set RPC_URL, PRIVATE_KEY)"
	@echo "  run         - Run deploy script locally"
	@echo "  fmt         - Format contracts"
	@echo "  clean       - Remove build artifacts"
	@echo "  gas         - Run gas report"
	@echo "  test-env    - Run tests with environment profile"
