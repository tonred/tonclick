pragma ton-solidity >= 0.48.0;


interface IRootWithdrawal {
    function getWithdrawalParams(TvmCell payload) external;
}
