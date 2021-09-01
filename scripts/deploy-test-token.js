const TOKEN_PATH = '../node_modules/ton-eth-bridge-token-contracts/free-ton/build';

async function main() {
  const [keyPair] = await locklift.keys.getKeyPairs();
  const TokenRoot = await locklift.factory.getContract('RootTokenContract');
  const TokenWallet = await locklift.factory.getContract('TONTokenWallet');
  const TestTIP3Deployer = await locklift.factory.getContract('TestTIP3Deployer');

  const testTIP3Deployer = await locklift.giver.deployContract({
    contract: TestTIP3Deployer,
    constructorParams: {
      root_code: TokenRoot.code,
      wallet_code: TokenWallet.code
    },
    initParams: {},
    keyPair,
  }, locklift.utils.convertCrystal(20, 'nano'))
  console.log(`Token Deployer address: ${testTIP3Deployer.address}`);
  const token = await testTIP3Deployer.run({method: 'deployRootTIP3', keyPair});
  console.log(`Test token address: ${token.decoded.out_messages[1].value.value0}`);
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.log(e);
    process.exit(1);
  });
