local types = {}

types.GEAR_STATE = {
    UP = 1,
    Moving = 2,
    DOWN = 3,
    LOCK = 4,
}
types.Wings = {
    forward = 1,
    Swept = 2
}

types.ENGN_F_STATE = {
    FIRE = 1,
    EXT = 2,
    NORM = 3
}
types.ENGN_STATE = {
    CUT = 1,
    WRN = 2,
    NORM = 3
}
types.PRIORITY = {
    BASIC          = "p0",
    ALERT          = "p1",
    CAUTION        = "p2",
    URGENT_CAUTION = "p3",
    WARNING        = "p4"

}

return types