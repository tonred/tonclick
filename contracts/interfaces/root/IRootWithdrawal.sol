pragma ton-solidity >= 0.47.0;


interface IRootWithdrawal {
    function getWithdrawalParams(TvmCell payload) external;
}
