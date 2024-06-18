Digital("digital_adapter_6")
Digital("digital_adapter_5")

Digital("digital_adapter_3")


Mon("monitor_0")
Mon("monitor_1")

Motor("L_Vstab","electric_motor_9")
    :Bearing("digital_adapter_6","south")

Motor("L_Hstab","electric_motor_7")
    :Bearing("digital_adapter_6","west")

Motor("R_Vstab","electric_motor_10")
    :Bearing("digital_adapter_5","north")

Motor("R_Hstab","electric_motor_8")
    :Bearing("digital_adapter_5","west")


Gear("Wing_Sweep","Create_SequencedGearshift_1")

Motor("GearR","electric_motor_5")
    :Bearing("digital_adapter_3","west")

Gear("Gear","Create_SequencedGearshift_2")
