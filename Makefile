setup:
	cp example.locklift.config.js locklift.config.js
	npm install -g locklift

compile:
	rm -rf build
	export TVM_LINKER_LIB_PATH=/Users/abionics/TON/Compilation/TON-Solidity-Compiler/lib/stdlib_sol.tvm && \
		locklift build --config locklift.config.js

deploy:
	locklift run -s scripts/deploy-root.js --config locklift.config.js --network local --disable-build

test:
	cd tests/ts4 && \
		python3 -m unittest tests.Tests
