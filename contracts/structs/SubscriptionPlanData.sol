pragma ton-solidity >= 0.48.0;


struct SubscriptionPlanData {
    string title;
    uint32 duration;
    string description;
    string termUrl;
    uint64 limitCount;  // todo bool is limited
    //    uint32 _maxPeriods;  // todo may be time limit (finish time)
}
