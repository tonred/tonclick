pragma ton-solidity >= 0.47.0;


interface IRootOnUserSubscription {
    function onUserSubscription(
        uint32 serviceNonce,
        address userSubscription,
        address sender,
        address user,
        uint256 pubkey
    ) external;
}
