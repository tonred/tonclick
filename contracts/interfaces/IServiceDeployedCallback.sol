pragma ton-solidity >= 0.47.0;

interface IServiceDeployedCallback {
    function onServiceDeployed(address service, uint32 nonce) external;
}
