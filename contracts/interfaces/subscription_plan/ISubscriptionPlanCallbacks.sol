pragma ton-solidity >= 0.47.0;


interface ISubscriptionPlanCallbacks {

    function subscribeCallback(
        address sender,
        address user,
        uint256 pubkey,
        bool firstCallback,
        bool isActivateAutoRenew
    ) external;

    function unsubscribeCallback(
        address sender,
        address user,
        uint256 pubkey,
        bool isDeactivateAutoRenew
    ) external;

}
