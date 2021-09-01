async function main() {
  const [keyPair] = await locklift.keys.getKeyPairs();
  const SignChecker = await locklift.factory.getContract('SignChecker');

  const signChecker = await locklift.giver.deployContract({
    contract: SignChecker,
    constructorParams: {},
    initParams: {},
    keyPair,
  }, locklift.utils.convertCrystal(0.5, 'nano'));
  console.log(`SignChecker address: ${signChecker.address}`);
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.log(e);
    process.exit(1);
  });
