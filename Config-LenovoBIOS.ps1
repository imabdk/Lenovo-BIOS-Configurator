<#
.SYNOPSIS
    Modify Lenovo BIOS from within Windows through WMI
.DESCRIPTION
    This script enables the ability to modify the BIOS of a Lenovo computer. If the script is run on a non-Lenovo computer, the script will exit.

    The script currently supports modifying following BIOS settings:

        - VirtualizationTechnology (enable/disable)
        - SecureBoot (enable/disable)
        - ThunderboltAccess (enable/disable)
        - SecurityChip (TPM) (enable/disable)
        - AMTControl (enable/disable)
        - OnByAcAttach (enable/disable)
        - WirelessAutoDisconnection (enable/disable)

    Further to above settings, the script is able to set the supervisor password via the parameter -SetSupervisorPass

.NOTES
    FileName:    Config-LenovoBIOS.ps1
    Author:      Martin Bengtsson
    Created:     20-08-2017
    Version:     2.0

    Version history:

    1.0   -   Script created
    2.0   -   Script updated

.LINK
    https://www.imab.dk/lenovo-bios-configurator
    https://www.imab.dk/configure-and-use-lenovo-bios-supervisor-password-during-osd-using-powershell-and-configuration-manager    
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [string]$SetSupervisorPass,
    [Parameter(Mandatory=$false)]
    [string]$SupervisorPass,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableVirtualization,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$DisableVirtualization,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableSecureBoot,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$DisableSecureBoot,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableThunderboltAccess,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$DisableThunderboltAccess,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableTPM,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$DisableTPM,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableAMT,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$DisableAMT,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableOnByAcAttach,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$DisableOnByAcAttach,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableWirelessAutoDisconnection,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$DisableWirelessAutoDisconnection,
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$Restart
)
#region Functions
# Create Write-Log function
function Write-Log {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,
        # EDIT with your location for the local log file
        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        [string]$Path="$env:SystemRoot\" + "Config-LenovoBIOS.log",
        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info",
        [Parameter(Mandatory=$false)]
        [switch]$NoClobber
    )
    Begin {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process {
        # if the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
        }
        # if attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            $NewLogFile = New-Item $Path -Force -ItemType File
        }
        else {
            # Nothing to see here yet
        }
        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
                }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
                }
            'Info' {
                Write-Verbose $Message
                $LevelText = 'INFO:'
                }
            }
        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
    }
    End {
        # Nothing to see here yet
    }
}

function Get-TaskSequenceStatus() {
	# Determine if a task sequence is currently running
	try {
		$tsEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
	}
	catch {
        $false
    }
	if (-NOT[string]::IsNullOrEmpty($tsEnv)) {
		$true
	}
}
#endregion
#region Variables
# Check if Lenovo computer. if not, stop script
$IsTaskSequence = Get-TaskSequenceStatus
$IsLenovo = (Get-CimInstance -ClassName Win32_ComputerSystemProduct).Vendor
#endregion

#region Execution
if ($IsLenovo -ne "LENOVO") {
    Write-Log -Message "Not a Lenovo laptop - exiting script"
    exit 0
}
else {
    if ($PSBoundParameters["SetSupervisorPass"]) {
        Write-Log -Message "Checking to see if a BIOS password already is present"
        $passwordState = (Get-WmiObject -Namespace root\wmi -Class Lenovo_BiosPasswordSettings).PasswordState
        switch ($passwordState) {
            0 { $returnMessage = 'No passwords set' }
            2 { $returnMessage = 'Supervisor password set' }
            3 { $returnMessage = 'Power on and supervisor passwords set' }
            4 { $returnMessage = 'Hard drive password(s) set' }
            5 { $returnMessage = 'Power on and hard drive passwords set' }
            6 { $returnMessage = 'Supervisor and hard drive passwords set' }
            7 { $returnMessage = 'Supervisor, power on, and hard drive passwords set' }
        }
        if ($passwordState -eq 0) {
            Write-Log -Message "No BIOS password is present. Moving on to configure the supervisor password"
            try {
                Write-Log -Message "Configuring supervisor password to: $SetSupervisorPass"
                $SetSupervisorPassword = Get-WmiObject -Namespace root\wmi -Class Lenovo_setBiosPassword
                $Invocation = $SetSupervisorPassword.SetBiosPassword("pap,$SetSupervisorPass,$SetSupervisorPass,ascii,us").Return
            }
            catch {
                Write-Log -Message "An error occured while configuring the supervisor password in the BIOS"
                Write-Log -Message "This can only be done programmatically while in System Deployment Mode"
            }
            if ($Invocation -eq "Success") {
                Write-Log -Message "Supervisor password successfully configured to: $SetSupervisorPass"
                if ($IsTaskSequence -eq $true) {
                    $tsEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
                    $tsEnv.Value('SMSTSBIOSPasswordStatus') = 2
                }            
            }
            elseif ($Invocation -ne "Success") {
                Write-Log -Message "Supervisor password is NOT configured. Output from WMI is: $Invocation"
                Write-Log -Message "This can only be done programmatically while in System Deployment Mode"
                if ($IsTaskSequence -eq $true) {
                    $tsEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
                    $tsEnv.Value('SMSTSBIOSPasswordStatus') = 0
                }   
            }
        }
        elseif ($passwordState -ne 0) {
            Write-Log -Message "A BIOS password is already configured. The return message is: $returnMessage"                
        }
    }
    if ($PSBoundParameters["SupervisorPass"]) {
        $Encoding = ",ascii,us"
        $Password1 = "," + $SupervisorPass + $Encoding
        $Password2 = $SupervisorPass + $Encoding
        $TestingPassword = ((Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2)).return
        if ($TestingPassword -eq "Success") {
            Write-Log -Message "Supervisor password entry succeeded"
        }
        else {
            Write-Log -Message "Password is incorrect! Please provide the correct supervisor password. Your entry was: $SuperVisorPass"
            exit 1
        }
    }
    else {
        # Setting dummy passwords. If no supervisor password is configured, Lenovo allows using any entry (apparently).
        Write-Log -Message "SupervisorPass parameter not used - using placeholder password. This line can be ignored if not configuring any BIOS settings"
        $Password1 = $null
        $Password2 = $null
    }
    
    # Virtualization, Enable
    if ($PSBoundParameters["EnableVirtualization"]) {
        # Getting information for Virtualization in BIOS. Output to variable
        $Virtualization = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "Virtualization*"} | Select-Object CurrentSetting
        $VirtualizationName = $Virtualization.CurrentSetting -split(',')
        $Name = $VirtualizationName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        # if virtualization is disabled, try to enable virtualization
        if ($Virtualization.CurrentSetting -eq "VirtualizationTechnology,Disable"){
            Write-Log -Message "$Name disabled - trying to enable" 
            # trying to modify the BIOS through calls to WMI. Also saving the settings in BIOS
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("VirtualizationTechnology,Enable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message "An error occured while enabling $Name in the BIOS"
            }
        }
        # if already enabled, do nothing
        elseif ($Virtualization.CurrentSetting -eq "VirtualizationTechnology,Enable") {
            Write-Log -Message "$Name already enabled - doing nothing"
        }
        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully enabled"
        }
        else { 
            # Nothing to see here yet
        }
    }

    # Virtualization, Disable    
    if ($PSBoundParameters["DisableVirtualization"]) {
    
        $Virtualization = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "Virtualization*"} | Select-Object CurrentSetting
        $VirtualizationName = $Virtualization.CurrentSetting -split(',')
        $Name = $VirtualizationName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"

        if ($Virtualization.CurrentSetting -eq "VirtualizationTechnology,Enable"){
            Write-Log -Message "$Name enabled - trying to disable"
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("VirtualizationTechnology,Disable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message "An error occured while disabling $Name in the BIOS"
            }
        }
        elseif ($Virtualization.CurrentSetting -eq "VirtualizationTechnology,Disable") {
            Write-Log -Message "$Name already disabled - doing nothing"
        }
        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully disabled"
        }
        else { 
            # Nothing to see here yet
        }
    }

    # SecureBoot, Enable
    if ($PSBoundParameters["EnableSecureBoot"]) {
        $SecureBoot = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "SecureBoot*"} | Select-Object CurrentSetting
        $SecureBootName = $SecureBoot.CurrentSetting -split(',')
        $Name = $SecureBootName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        if ($SecureBoot.CurrentSetting -eq "SecureBoot,Disable") {
            Write-Log -Message "$Name disabled - trying to enable" 
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("SecureBoot,Enable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message "An error occured while enabling $Name in the BIOS"
            }
        }
        elseif ($SecureBoot.CurrentSetting -eq "SecureBoot,Enable") {
            Write-Log -Message "$Name already enabled - doing nothing"
        }
        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully enabled"
        }
        else { 
            # Nothing to see here yet
        }
    }

    # SecureBoot, Disable
    if ($PSBoundParameters["DisableSecureBoot"]) {
        $SecureBoot = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "SecureBoot*"} | Select-Object CurrentSetting
        $SecureBootName = $SecureBoot.CurrentSetting -split(',')
        $Name = $SecureBootName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        if ($SecureBoot.CurrentSetting -eq "SecureBoot,Enable") {
            Write-Log -Message "$Name enabled - trying to disable"

            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("SecureBoot,Disable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message "An error occured while disabling $Name in the BIOS"
            }
        }
        elseif ($SecureBoot.CurrentSetting -eq "SecureBoot,Disable") {
            Write-Log -Message "$Name already disabled - doing nothing"
        }
        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully disabled"
        }
        else { 
            # Nothing to see here yet
        }
    }

    # ThunderboltAccess, Enable
    if ($PSBoundParameters["EnableThunderboltAccess"]) {
        $ThunderboltAccess = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "ThunderboltAccess"} | Select-Object CurrentSetting
        $ThunderboltAccessName = $ThunderboltAccess.CurrentSetting -split(',')
        $Name = $ThunderboltAccessName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        if ($ThunderboltAccess.CurrentSetting -eq "ThunderboltAccess,Disable") {
            Write-Log -Message "$Name disabled - trying to enable" 
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("ThunderboltAccess,Enable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message "An error occured while enabling $Name in the BIOS"
            }
        }
        elseif ($ThunderboltAccess.CurrentSetting -eq "ThunderboltAccess,Enable") {
            Write-Log -Message "$Name already enabled - doing nothing"
        }
        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully enabled"
        }
        else { 
            # Nothing to see here yet
        }
    }

    # ThunderboltAccess, Disable
    if ($PSBoundParameters["DisableThunderboltAccess"]) {
        $ThunderboltAccess = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "ThunderboltAccess"} | Select-Object CurrentSetting
        $ThunderboltAccessName = $ThunderboltAccess.CurrentSetting -split(',')
        $Name = $ThunderboltAccessName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        if ($ThunderboltAccess.CurrentSetting -eq "ThunderboltAccess,Enable") {
            Write-Log -Message "$Name enabled - trying to disable"
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("ThunderboltAccess,Disable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
                }
            catch {
                Write-Log -Message "An error occured while disabling $Name in the BIOS"
            }
        }
        elseif ($ThunderboltAccess.CurrentSetting -eq "ThunderboltAccess,Disable") {
            Write-Log -Message "$Name already disabled - doing nothing"
        }

        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully disabled"
        }
        else { 
            # Nothing to see here yet
        }
    }

    # TPM (SecurityChip), Enable
    if ($PSBoundParameters["EnableTPM"]) {
        $TPM = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "SecurityChip"} | Select-Object CurrentSetting
        $TPMName = $TPM.CurrentSetting -split(',')
        $Name = $TPMName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        if ($TPM.CurrentSetting -eq "SecurityChip,Disable") {
            Write-Log -Message "$Name disabled - trying to enable" 
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("SecurityChip,Enable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message "An error occured while enabling $Name in the BIOS"
            }
        }
        elseif ($TPM.CurrentSetting -eq "SecurityChip,Enable") {
            Write-Log -Message "$Name already active - doing nothing"
        }
        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully enabled"
        }
        else { 
            # Nothing to see here yet
        }
    }

    # TPM (SecurityChip), Disable
    if ($PSBoundParameters["DisableTPM"]) {
        $TPM = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "SecurityChip"} | Select-Object CurrentSetting
        $TPMName = $TPM.CurrentSetting -split(',')
        $Name = $TPMName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        if ($TPM.CurrentSetting -eq "SecurityChip,Enable") {
            Write-Log -Message "$Name enabled - trying to disable"
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("SecurityChip,Disable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message "An error occured while disabling $Name in the BIOS"
            }
        }
        elseif ($TPM.CurrentSetting -eq "SecurityChip,Disable") {
            Write-Log -Message "$Name already disabled - doing nothing"
        }
        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully disabled"
        }
        else { 
            # Nothing to see here yet
        }
    }

    # AMT, Enable
    if ($PSBoundParameters["EnableAMT"]) {
        $AMT = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "AMTControl"} | Select-Object CurrentSetting
        $AMTName = $AMT.CurrentSetting -split(',')
        $Name = $AMTName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        if ($AMT.CurrentSetting -eq "AMTControl,Disable") {
            Write-Log -Message "$Name disabled - trying to enable" 
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("AMTControl,Enable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message Write-Log -Message "An error occured while enabling $Name in the BIOS"
            }
        }
        elseif ($AMT.CurrentSetting -eq "AMTControl,Enable") {
            Write-Log -Message "$Name already enabled - doing nothing"
        }

        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully enabled"
        }
        else { 
            # Nothing to see here yet
        }
    }

    # AMT, Disable
    if ($PSBoundParameters["DisableAMT"]) {
        $AMT = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "AMTControl"} | Select-Object CurrentSetting
        $AMTName = $AMT.CurrentSetting -split(',')
        $Name = $AMTName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        if ($AMT.CurrentSetting -eq "AMTControl,Enable") {
            Write-Log -Message "$Name enabled - trying to disable"
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("AMTControl,Disable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message "An error occured while disabling $Name in the BIOS"
            }
        }
        elseif ($AMT.CurrentSetting -eq "AMTControl,Disable") {
            Write-Log -Message "$Name already disabled - doing nothing"
        }

        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully disabled"
        }
        else { 
            # Nothing to see here yet
        }
    }

    # OnByAcAttach, Enable
    if ($PSBoundParameters["EnableOnByAcAttach"]) {
        $OnByAcAttach = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "OnByAcAttach"} | Select-Object CurrentSetting
        $OnByAcAttachName = $OnByAcAttach.CurrentSetting -split(',')
        $Name = $OnByAcAttachName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        if ($OnByAcAttach.CurrentSetting -eq "OnByAcAttach,Disable") {
            Write-Log -Message "$Name disabled - trying to enable"              
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("OnByAcAttach,Enable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message "An error occured while enabling $Name in the BIOS"
            }
        }
        elseif ($OnByAcAttach.CurrentSetting -eq "OnByAcAttach,Enable") {
            Write-Log -Message "$Name already enabled - doing nothing"
        }
        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully enabled"
        }
        else { 
            # Nothing to see here yet
        }
    }

    # OnByAcAttach, Disable
    if ($PSBoundParameters["DisableOnByAcAttach"]) {
        $OnByAcAttach = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "OnByAcAttach"} | Select-Object CurrentSetting
        $OnByAcAttachName = $OnByAcAttach.CurrentSetting -split(',')
        $Name = $OnByAcAttachName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        if ($OnByAcAttach.CurrentSetting -eq "OnByAcAttach,Enable") {
            Write-Log -Message "$Name enabled - trying to disable"
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("OnByAcAttach,Disable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message "An error occured while disabling $Name in the BIOS"
            }
        }
        elseif ($OnByAcAttach.CurrentSetting -eq "OnByAcAttach,Disable") {
            Write-Log -Message "$Name already disabled - doing nothing"
        }
        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully disabled"
        }
        else { 
            # Nothing to see here yet
        }
    }

    # WirelessAutoDisconnection, Enable
    if ($PSBoundParameters["EnableWirelessAutoDisconnection"]) {
        $WirelessAutoDisconnection = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "WirelessAutoDisconnection"} | Select-Object CurrentSetting
        $WirelessAutoDisconnectionName = $WirelessAutoDisconnection.CurrentSetting -split(',')
        $Name = $WirelessAutoDisconnectionName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        if ($WirelessAutoDisconnection.CurrentSetting -eq "$Name,Disable") {
            Write-Log -Message "$Name disabled - trying to enable"              
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("$Name,Enable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message "An error occured while enabling $Name in the BIOS"
            }
        }
        elseif ($WirelessAutoDisconnection.CurrentSetting -eq "$Name,Enable") {
            Write-Log -Message "$Name already enabled - doing nothing"
        }
        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully enabled"
        }
        else { 
            # Nothing to see here yet                
        }
    }

    # WirelessAutoDisconnection, Disable
    if ($PSBoundParameters["DisableWirelessAutoDisconnection"]) {
        $WirelessAutoDisconnection = Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | Where-Object {$_.CurrentSetting -match "WirelessAutoDisconnection"} | Select-Object CurrentSetting
        $WirelessAutoDisconnectionName = $WirelessAutoDisconnection.CurrentSetting -split(',')
        $Name = $WirelessAutoDisconnectionName[0]
        Write-Log -Message "Collected Lenovo_BiosSetting information for $Name"
        if ($WirelessAutoDisconnection.CurrentSetting -eq "$Name,Enable") {
            Write-Log -Message "$Name enabled - trying to disable"
            try {
                $Invocation = (Get-WmiObject -Class Lenovo_SetBiosSetting -Namespace root\wmi).SetBiosSetting("$Name,Disable$Password1").return
                $Invocation = (Get-WmiObject -Class Lenovo_SaveBiosSettings -Namespace root\wmi).SaveBiosSettings($Password2).return
            }
            catch {
                Write-Log -Message "An error occured while disabling $Name in the BIOS"
            }
        }
        elseif ($WirelessAutoDisconnection.CurrentSetting -eq "$Name,Disable") {
            Write-Log -Message "$Name already disabled - doing nothing"
        }
        if ($Invocation -eq "Success") {
            Write-Log -Message "$Name was successfully disabled"
        }
        else { 
            # Nothing to see here yet            
        }
    }

    # Restart computer
    if ($PSBoundParameters["Restart"]) {
        Write-Log -Message "Rebooting the computer"
        Restart-Computer -Force
    }
}
#endregion
#Getting all Lenovo BiosSettings
#Get-WmiObject -Class Lenovo_BiosSetting -Namespace root\WMI | select currentsetting