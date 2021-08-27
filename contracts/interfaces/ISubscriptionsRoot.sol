pragma ton-solidity >= 0.47.0;


interface ISubscriptionsRoot {
    function createService(string description, string url) external;
    function createSubscriptionPlan(uint32 serviceNonce, uint32 subscriptionPlanNonce) external;
}
