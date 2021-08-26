pragma ton-solidity >= 0.39.0;


library Errors {
    uint8 constant IS_NOT_OWNER = 101;
    uint8 constant IS_NOT_ROOT = 102;
    uint8 constant IS_NOT_SERVICE = 103;
    uint8 constant IS_NOT_SUBSCRIPTION_PLAN = 104;
    uint8 constant IS_NOT_USER_SUBSCRIPTION = 105;
    uint8 constant NOT_ENOUGH_TOKENS = 106;
    uint8 constant IS_NOT_TIP3_ROOT = 107;
    uint8 constant IS_NOT_TIP3_OWNER = 108;

    uint8 constant SERVICE_ZERO_TIP3_TOKENS = 120;
}
