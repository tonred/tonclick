pragma ton-solidity >= 0.47.0;


interface IServiceSubscribeCallback {
    function subscribeCallback(
        uint32 subscriptionPlanNonce,
        address tip3Root,
        address sender,
        address user,
        uint256 pubkey,
        uint128 changeAmount,
        address userSubscription
    ) external;
}
