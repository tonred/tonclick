pragma ton -solidity >=0.39.0;

import "./IOnchain.sol";
import "../Service.sol";

import "../../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";


contract OnchainDemo is IOnchain {

    uint128 public gift = 10 ton;  // just a sample

    constructor(
        address root,
        address service,
        address[] subscriptionPlans,
        uint128 minValue
    ) public IOnchain(root, service, subscriptionPlans, minValue) {
        tvm.accept();
    }

    function _action(address user, TvmCell /*payload*/) internal override {
        tvm.accept();
        user.transfer({value: gift});  // just a sample
        // do something with payload...
    }

}
