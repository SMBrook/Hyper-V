
$VHDDownload = "http://download.microsoft.com/download/5/8/1/58147EF7-5E3C-4107-B7FE-F296B05F435F/9600.16415.amd64fre.winblue_refresh.130928-2229_server_serverdatacentereval_en-us.vhd"
$downloadedFile = "C:\BuildArtifacts\server2012r2.vhd"

New-VMSwitch -SwitchName vNAT -SwitchType Internal

New-NetIPAddress -IPAddress 192.168.200.1 -PrefixLength 25 -InterfaceAlias "vEthernet (vNAT)"

New-NetNat -Name vNATNetwork -InternalIPInterfaceAddressPrefix 192.168.200.0/25 -Verbose
				
				Invoke-WebRequest $VHDDownload -OutFile $downloadedFile
				New-VM -Name AD01
					   -MemoryStartupBytes 2GB
					   -BootDevice VHD
					   -VHDPath 'C:\VM\server2012r2.vhd'