pragma ton-solidity >= 0.48.0;


interface IServiceSubscribeCallback {
    function subscribeCallback(
        uint32 subscriptionPlanNonce,
        address tip3Root,
        address senderWallet,
        address senderAddress,
        bool success,
        uint128 changeTip3Amount
    ) external;
}
