pragma ton-solidity >= 0.47.0;


interface IServiceAddTip3Wallets {
    function addTip3Wallets(uint32 subscriptionPlanNonce, mapping(address => uint128) tip3Prices) external;
}
