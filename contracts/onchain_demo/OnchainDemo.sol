pragma ton-solidity >=0.39.0;

import "../Service.sol";

import "../../node_modules/@broxus/contracts/contracts/libraries/MsgFlag.sol";


contract OnchainDemo {

    address _root;
    // todo subscription plan
    address _service;


//    constructor(address root, address _service) public {
//        tvm.accept();
//        _root = root;
//        _service = _service;
//    }
//
//    // Only user with subscription can get tokens
//    function getTokens(uint32 subscriptionPlanNonce) public {
//        address user = msg.sender;
//        Service(_service)
//            .getSubscriptionPlanByIndex{
//                value: 0,
//                flag: MsgFlag.REMAINING_GAS,
//                callback: serviceCallback,
//                bounce: true
//            }(subscriptionPlanNonce);
//    }

//    function serviceCallback(address subscriptionPlan) {
//        require(msg.sender == _service, 999);
//        SubscriptionPlan(_subscriptionPlan).
//            getUserSubscription{
//
//            }();
//    }

}
