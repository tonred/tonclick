pragma ton-solidity >= 0.47.0;

import "../tip3/interfaces/ITokenWalletDeployedCallback.sol";

import './../../node_modules/@broxus/contracts/contracts/wallets/Account.sol';


contract Wallet is Account, ITokenWalletDeployedCallback {
    function notifyWalletDeployed(address /*root*/) public override {
//        tvm.log("notifyWalletDeployed");
    }
}
