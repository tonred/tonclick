pragma ton-solidity >= 0.47.0;

import "./Fallbacks.sol";


interface IOnchainCallbacks {
    function onchainFallback(Fallbacks reason) external;  // check sender in implementation
    function onchainSuccess() external;  // check sender in implementation
}
