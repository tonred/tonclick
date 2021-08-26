pragma ton-solidity >= 0.48.0;


interface IRootCreateSubscriptionPlan {
    function createSubscriptionPlan(
        uint32 serviceNonce,  // todo use TvmCell
        uint32 subscriptionPlanNonce,
        address owner,
        address service,
        mapping(address => uint128) tip3Prices,  // second TvmCell
        uint32 duration,
        uint128 limitCount,
        string description,
        string termUrl
    ) external;
}
