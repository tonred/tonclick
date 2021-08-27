pragma ton-solidity >= 0.48.0;


interface ISubscriptionPlanCallbacks {

    function subscribeCallback(
        address user,
        uint256 pubkey,
        bool isFirstCallback,
        bool isActivateAutoRenew
    ) external;

    function unsubscribeCallback(
        address user,
        uint256 pubkey,
        bool isDeactivateAutoRenew
    ) external;

}
