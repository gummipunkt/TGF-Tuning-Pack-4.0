Function GetFailingDrive { 
<# 
.SYNOPSIS 
    Checks for any potentially failing drives and reports back drive information. 
     
.DESCRIPTION 
    Checks for any potentially failing drives and reports back drive information. This only works 
    against local hard drives using SMART technology. Reason values and their meanings can be found 
    here: http://en.wikipedia.org/wiki/S.M.A.R.T#Known_ATA_S.M.A.R.T._attributes 
     
.PARAMETER Computer 
    Remote or local computer to check for possible failed hard drive. 
     
.PARAMETER Credential 
    Provide alternate credential to perform query. 
 
.NOTES 
    Author: Boe Prox 
    Version: 1.0 
    http://learn-powershell.net 
 
.EXAMPLE 
    GetFailingDrive 
     
    WARNING: ST9320320AS ATA Device may fail! 
 
 
    MediaType       : Fixed hard disk media 
    InterFace       : IDE 
    DriveName       : ST9320320AS ATA Device 
    Reason          : 1 
    SerialNumber    : 202020202020202020202020533531584e5a4d50 
    FailureImminent : True 
     
    Description 
    ----------- 
    Command ran against the local computer to check for potential failed hard drive. 
#> 

    [cmdletbinding()] 
    Param ( 
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)] 
        [string[]]$Computername=$Env:Computername, 
        [parameter()] 
        [Alias('RunAs')]        
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    ) 
    Begin { 
        If ($PSBoundParameters.ContainsKey('Debug')) {
            $DebugPreference = 'Continue'
        }
        $PSBoundParameters.GetEnumerator() | ForEach {
            Write-Debug $_
        }
        $queryhash = @{
            NameSpace = 'root\wmi'
            Class = 'MSStorageDriver_FailurePredictStatus' 
            Filter = "PredictFailure='True'" 
            ErrorAction = 'Stop'
        } 
        $BadDriveHash = @{
            DiskDrive = 'win32_diskdrive' 
            ErrorAction = 'Stop' 
        } 
    } 
    Process {
        $FailingDrivesArray = @() 
        ForEach ($Computer in $Computername) { 
            $queryhash['Computername'] = $Computer 
            $BadDriveHash['Computername'] = $Computer 
            If ($PSBoundParameters['Credential']) { 
                $queryhash['Credential'] = $Credential 
                $BadDriveHash['Credential'] = $Credential 
            }              
            [regex]$regex = "(?<DriveName>\w+\\[A-Za-z0-9_]*)\w+" 
            Try { 
                Write-Verbose "[$($Computer)] Checking for failed drives" 
                $FailingDrives = Get-WMIObject @queryhash
                If ($FailingDrives) {
                    Write-Verbose "Found drives that may fail; gathering more information."
                    $FailingDrives | ForEach { 
                        $drive = $regex.Matches($_.InstanceName) | ForEach {
                            $_.Groups['DriveName'].value
                        } 
                        $BadDrive = Get-WMIObject @BadDriveHash | Where {
                            $_.PNPDeviceID -like "$drive*"
                        } 
                        If ($BadDrive) { 
                            Write-Warning "$($BadDriveHash['Computername']): $($BadDrive.Model) may fail!" 
                            $DriveList = New-Object PSObject -Property @{ 
                                DriveName = $BadDrive.Model 
                                FailureImminent  = $_.PredictFailure 
                                Reason = $_.Reason 
                                MediaType = $BadDrive.MediaType 
                                SerialNumber = $BadDrive.SerialNumber 
                                InterFace = $BadDrive.InterfaceType 
                                Partitions = $BadDrive.Partitions 
                                Size = $BadDrive.Size 
                                Computer = $BadDriveHash['Computername'] 
                            }
                            $FailingDrivesArray += $DriveList
                        } 
                    } 
                }
            } Catch { 
                Write-Warning "$($Error[0])" 
            } 
        } 
        return $FailingDrivesArray
    } 
}
