pragma ton-solidity >= 0.47.0;

import "../../structs/SubscriptionPlanData.sol";


interface IRootCreateSubscriptionPlan {
    function createSubscriptionPlan(
        uint32 serviceNonce,  // todo use TvmCell
        uint32 subscriptionPlanNonce,
        address owner,
        address service,
        SubscriptionPlanData data,
        mapping(address /*root*/ => uint128 /*price*/) tip3Prices
    ) external;
}
