Import-Module CimCmdlets
Add-Type @"
public enum ShutdownType {
    LogOff = 0,
    Shutdown = 1,
    Reboot = 2,
    PowerOff = 8
}

public enum ShutDown_MajorReason {
    APPLICATION = 0x00040000,
    HARDWARE = 0x00010000,
    LEGACY_AP = 0x00070000,
    OPERATINGSYSTEM = 0x00020000,
    OTHER = 0x00000000,
    POWER = 0x00060000,
    SOFTWARE = 0x00030000,
    SYSTEM = 0x00050000
}

public enum ShutDown_MinorReason {
    BLUESCREEN = 0x0000000F,
    CORDUNPLUGGED = 0x0000000b,
    DISK = 0x00000007,
    ENVIRONMENT = 0x0000000c,
    HARDWARE_DRIVER = 0x0000000d,
    HOTFIX = 0x00000011,
    HOTFIX_UNINSTALL = 0x00000017,
    HUNG = 0x00000005,
    INSTALLATION = 0x00000002,
    MAINTENANCE = 0x00000001,
    MMC = 0x00000019,
    NETWORK_CONNECTIVITY = 0x00000014,
    NETWORKCARD = 0x00000009,
    OTHER = 0x00000000,
    OTHERDRIVER = 0x0000000e,
    POWER_SUPPLY = 0x0000000a,
    PROCESSOR = 0x00000008,
    RECONFIG = 0x00000004,
    SECURITY = 0x00000013,
    SECURITYFIX = 0x00000012,
    SECURITYFIX_UNINSTALL = 0x00000018,
    SERVICEPACK = 0x00000010,
    SERVICEPACK_UNINSTALL = 0x00000016,
    TERMSRV = 0x00000020,
    UNSTABLE = 0x00000006,
    UPGRADE = 0x00000003,
    WMI = 0x00000015
}
"@