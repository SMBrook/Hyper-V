Configuration InstallWindowsFeatures {

    Import-DscResource -ModuleName PsDesiredStateConfiguration

    Node "localhost" {

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
            ActionAfterReboot  = 'ContinueConfiguration'
        }

        WindowsFeature Hyper-V {
            Name   = "Hyper-V"
            Ensure = "Present"
        }

        WindowsFeature RSAT-Hyper-V-Tools {
            Name = "RSAT-Hyper-V-Tools"
            Ensure = "Present"
        }
       
    }
}