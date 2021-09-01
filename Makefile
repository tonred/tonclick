help:
	@echo "[*] setup - setup environment"
	@echo "[*] compile - compile all contracts"
	@echo "[*] deploy-root - deploy root"
	@echo "[*] test - test all contracts"
	@echo "[*]   test-contracts - test only contracts"
	@echo "[*]   test-onchain-demo - test only onchain demo"

setup:
	cp example.locklift.config.js locklift.config.js
	npm install
	npm install -g locklift

compile:
	rm -rf build
	export TVM_LINKER_LIB_PATH=/Users/abionics/TON/Compilation/TON-Solidity-Compiler/lib/stdlib_sol.tvm && \
		locklift build --config locklift.config.js

deploy: deploy-root deploy-signchecker

deploy-root:
	locklift run -s scripts/deploy-root.js --config locklift.config.js --network local --disable-build

deploy-debot:
	locklift run -s scripts/deploy-debot.js --config locklift.config.js --network local --disable-build

deploy-signchecker:
	locklift run -s scripts/deploy-signchecker.js --config locklift.config.js --network local --disable-build

test: test-contracts test-onchain-demo

test-contracts:
	$(call unittest-execute,test_contacts,TestContacts)

test-onchain-demo:
	$(call unittest-execute,test_onchain_demo,TestOnchainDemo)

define unittest-execute
	@echo "Testing $(2)"
	cd tests/ts4 && \
		python3 -m unittest $(1).$(2)
endef
