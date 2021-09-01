const stringToBytesArray = (dataString) => {
  return Buffer.from(dataString).toString('hex')
};
const img = 'iVBORw0KGgoAAAANSUhEUgAAAJYAAACWBAMAAADOL2zRAAAAAXNSR0IB2cksfwAAAAlwSFlzAAAXEgAAFxIBZ5/SUgAAACRQTFRFAAAAHZ6gi+LkqeTmy/T1XM3GFhYW////p+fpgtLVP8K5nePmaklZLwAAAAx0Uk5TAP//////////////CcRQJgAAAZ9JREFUeJzt2D1uwkAQBWDTUDNJkJJ05AaIE0TyBSjooZlIOYBdp0ubMqVbrsDl2Fk7y673hywQIuH3GtAavmZm1l4XBYIgCIIg1wxlZALrctZIfnH34iW4OJMfw7qMNaL7hcqcqC+V5au/OF2pxIoJK8eiVtKx/jgTScddXP1kGdBu3lINv3DSdTrRQ3mIWZyu7Czd9oeVY42sEiYt5pDltD+sHIt8STKX7bx0wyob6kNdMSeDsX4d5rqumONPKrByrcfPcIi+3Yilwvy+7aeBdYIle05Yi1lSTFez96/bt/T98XSr8e61WZYepQFbsfYnerIosizT/k3wGRNWjhUcpaQlxdxEz0O3bwXa/6i1jkj5lh6lAVuF3/4fZuMh2vpWLe0fKwCsPKtfzONWqv2HYOkC/JuVHKUhWG77i/alpK1nVXwIrEtZ9igFrIrf2o91ioB1olWYUfIs2eHH7ffk8AzN6tp/tyN61qfE7l2HXIH111bX/tpSp0TZW9bmErfNn3o2gXWOVZiXgN46rLgWPiWOj90YYZ1tIQhylewBK4B7rwsrJD0AAAAASUVORK5CYII=';
const root = '';

const deployDobot = async (contract, image) => {
  const [keyPair] = await locklift.keys.getKeyPairs();

  const debot = await locklift.giver.deployContract({
    contract: contract,
    constructorParams: {},
    initParams: {},
    keyPair,
  }, locklift.utils.convertCrystal(0.5, 'nano'))
  debot.setKeyPair(keyPair);

  await debot.run({
    method: 'setABI',
    params: {dabi: stringToBytesArray(JSON.stringify(debot.abi))}
  });
  await debot.run({
    method: 'setRoot',
    params: {root}
  });
  await debot.run({
    method: 'setIcon',
    params: {icon: stringToBytesArray('data:image/png;base64,' + image)}
  });
  return debot;
}

async function main() {
  const ServiceDebot = await locklift.factory.getContract('ServiceDebot');
  const UserDebot = await locklift.factory.getContract('UserDebot');

  console.log(`ServiceDebot address: ${(await deployDobot(ServiceDebot, img)).address}`);
  console.log(`UserDebot address: ${(await deployDobot(UserDebot, img)).address}`);
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.log(e);
    process.exit(1);
  });
