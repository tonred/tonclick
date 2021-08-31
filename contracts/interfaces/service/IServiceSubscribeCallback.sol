pragma ton-solidity >= 0.47.0;


interface IServiceSubscribeCallback {
    function subscribeCallback(
        uint32 subscriptionPlanNonce,
        address tip3Root,
        address sender,
        bool success,
        uint128 changeAmount
    ) external;
}
