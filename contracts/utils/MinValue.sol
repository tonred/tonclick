pragma ton-solidity >= 0.39.0;

import "../libraries/Errors.sol";


abstract contract MinValue {

    modifier minValue(uint128 value) {
        require(msg.value >= value, Errors.NOT_ENOUGH_TOKENS);
        _;
    }

}
