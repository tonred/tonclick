pragma ton-solidity >= 0.47.0;


struct SubscriptionPlanData {
    string title;
    uint32 duration;
    string description;
    string termUrl;
    uint64 limitCount;
    //    uint32 finishTime;  // todo add
}
