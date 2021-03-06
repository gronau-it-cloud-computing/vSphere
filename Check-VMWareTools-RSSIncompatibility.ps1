##########################################################################################
# Name: Check-VMWareTools-RSSIncompatibility.ps1
# Author: Adrian Begg (adrian.begg@ehloworld.com.au)
#
# Date: 28/04/2017
# Purpose: A quick script to check if the machines are affected by the bug dscribed in
# https://blogs.vmware.com/apps/2017/03/rush-post-vmware-tools-rss-incompatibility-issues.html
#
# Outputs objects to a CSV at $strCSVOutput
#
# The script assumes that all of the machines targeted are ton the same domain for the Invoke-Guest call
# Use the Get-Cluster/Get-ResourcePool in $vm's to filter
#
# Outputs a list of Windows Server 2012/2012 R2 machines with VMXNet3 adapters and the Tools Version and
# and if the RSS Feature has been enabled on the guestCredentials
##########################################################################################
[string] $strvCenter = "labvc1.pigeonnuggets.com"
[string] $strCSVOutput = "C:\Temp\RSSIncompatibility.csv"

Connect-VIServer $strvCenter

$vms = Get-VM
$guestCredentials = Get-Credential

$colVMs = $vms | ?{($_.ExtensionData.Config.Tools.ToolsVersion -gt "9100") -and ($_.ExtensionData.Config.Tools.ToolsVersion -lt "10150") -and (($_ | Get-NetworkAdapter).Type -contains "Vmxnet3") -and (($_.ExtensionData.Guest.GuestId -eq "windows8Server64Guest") -or ($_.ExtensionData.Guest.GuestId -eq "windows9Server64Guest"))}
# Decalre a collection for storing the StorageProfile Configuarations for each VM
$colVMSResult = New-Object -TypeName System.Collections.ArrayList
foreach($vm in $colVMs){
	# Check if the machine is PoweredOn
	If($vm.PowerState -eq "PoweredOn"){
		Try{
			$RSSEnabled = (Invoke-VMScript -VM $vm -ScriptText "(Get-NetAdapterRss).Enabled" -GuestCredential $guestCredentials -WarningAction SilentlyContinue).ScriptOutput
			$objResult = $vm | Select Name,@{name="ToolsVersion"; expression={$_.ExtensionData.Config.Tools.ToolsVersion}}, @{name="Guest"; expression={$_.ExtensionData.Guest.GuestFullName}}, @{name="RSSEnabled"; expression={$RSSEnabled}}
			$colVMSResult.Add($objResult) > $nul
		} Catch {
			$objResult = $vm | Select Name,@{name="ToolsVersion"; expression={$_.ExtensionData.Config.Tools.ToolsVersion}}, @{name="Guest"; expression={$_.ExtensionData.Guest.GuestFullName}}, @{name="RSSEnabled"; expression={"Unknown"}}
			$colVMSResult.Add($objResult) > $nul
		}
	} else {
		$objResult = $vm | Select Name,@{name="ToolsVersion"; expression={$_.ExtensionData.Config.Tools.ToolsVersion}}, @{name="Guest"; expression={$_.ExtensionData.Guest.GuestFullName}}, @{name="RSSEnabled"; expression={"Unknown"}}
		$colVMSResult.Add($objResult) > $nul
	}
}
$colVMSResult | Export-CSV -NoTypeInformation $strCSVOutput
Disconnect-VIServer
