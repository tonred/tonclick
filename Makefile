setup:
	cp example.locklift.config.js locklift.config.js
	npm install -g locklift

compile:
	rm -rf build
	export TVM_LINKER_LIB_PATH=/Users/abionics/TON/Compilation/TON-Solidity-Compiler/lib/stdlib_sol.tvm && \
		locklift build --config locklift.config.js

deploy:
	locklift run -s scripts/deploy-root.js --config locklift.config.js --network local --disable-build

tests: tests-root tests-service tests-subscription-plan
	@echo "Testing all"

tests-root:
	$(call unittest-execute,root,RootTest)

tests-service:
	$(call unittest-execute,service,ServiceTest)

tests-subscription-plan:
	$(call unittest-execute,subscription_plan,SubscriptionPlanTest)

define unittest-execute
	@echo "Testing $(2)"
	cd tests/ts4 && \
		python3 -m unittest $(1).$(2)
endef
