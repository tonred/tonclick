pragma ton-solidity >= 0.39.0;

import "../utils/Wallet.sol";
import "../onchain/Fallbacks.sol";
import "../onchain/IOnchainCallbacks.sol";


contract TestOnchainWallet is Wallet, IOnchainCallbacks {
    bool public _success;
    Fallbacks public _reason;

    function onchainFallback(Fallbacks reason) public override {
        tvm.accept();
        _success = false;
        _reason = reason;
    }

    function onchainSuccess() public override {
        tvm.accept();
        _success = true;
    }
}
