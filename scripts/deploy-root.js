const afterRun = async (tx) => {
    await new Promise(resolve => setTimeout(resolve, 2000));
};

const deployAccount = async function (key, value) {
    const Account = await locklift.factory.getAccount('Wallet');
    let account = await locklift.giver.deployContract({
        contract: Account,
        constructorParams: {},
        keyPair: key
    }, locklift.utils.convertCrystal(value, 'nano'));
    account.setKeyPair(key);
    account.afterRun = afterRun;
    return account;
}

async function main() {
  const [keyPair] = await locklift.keys.getKeyPairs();
  const owner = await deployAccount(keyPair, 10);
  const Root = await locklift.factory.getContract('Root');
  const Service = await locklift.factory.getContract('Service');
  const SubscriptionPlan = await locklift.factory.getContract('SubscriptionPlan');
  const UserSubscription = await locklift.factory.getContract('UserSubscription');
  const UserProfile = await locklift.factory.getContract('UserProfile');

  const root = await locklift.giver.deployContract({
    contract: Root,
    constructorParams: {
      owner,
      serviceCode: Service.code,
      subscriptionPlanCode: SubscriptionPlan.code,
      userSubscriptionCode: UserSubscription.code,
      userProfileCode: UserProfile.code,
    },
    initParams:{
      // _randomNonce: 0
    },
    keyPair,
  }, locklift.utils.convertCrystal(2, 'nano'));
  console.log(`Root address: ${root.address}`);
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.log(e);
    process.exit(1);
  });
