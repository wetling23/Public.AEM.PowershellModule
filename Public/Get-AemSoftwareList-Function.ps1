Function Get-AemSoftwareList {
    <#
        .DESCRIPTION
            Accepts a device UID and returns a list of installed applications.
        .NOTES
            V1.0.0.0 date: 17 August 2018
                - Initial release.
        .PARAMETER
        .EXAMPLE
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [string]$AemAccessToken,

        [Parameter(Mandatory = $True, ParameterSetName = 'IdFilter')]
        [int]$DeviceId,

        [Parameter(Mandatory = $True, ParameterSetName = 'UidFilter')]
        [string]$DeviceUid,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [string]$EventLogSource = 'AemPowerShellModule',

        [switch]$BlockLogging
    )

    Begin {
        If (-NOT($BlockLogging)) {
            $return = Add-EventLogSource -EventLogSource $EventLogSource

            If ($return -ne "Success") {
                $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
                Write-Host $message -ForegroundColor Yellow;

                $BlockLogging = $True
            }
        }
    }

    Process {
        $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

        # Setup the parameters for Get-AemDevices.
        If (($PSBoundParameters['Verbose'])) {
            $deviceQueryParams = @{
                AemAccessToken = $AemAccessToken
                Verbose        = $True
            }
        }
        Else {
            $deviceQueryParams = @{
                AemAccessToken = $AemAccessToken
            }
        }
        If ($BlockLogging) {
            $deviceQueryParams.add("BlockLogging", $True)
        }
        Else {
            $deviceQueryParams.add("EventLogSource", $EventLogSource)
        }

        Switch ($PsCmdlet.ParameterSetName) {
            "IdFilter" {
                $DeviceUId = (Get-AemDevices -DeviceId $DeviceId @deviceQueryParams).Uid
            }
        }

        If ($DeviceId -as [int]) {
            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/audit/device/$DeviceUid/software"
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
            }

            $message = ("{0}: Getting installed applications." -f (Get-Date -Format s))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            Try {
                $webResponse = Invoke-WebRequest @params -ErrorAction Stop | ConvertFrom-Json
            }
            Catch {
                $message = ("{0}: It appears that the web request failed. The specific error message is: {1}" -f (Get-Date -Format s), $_.Exception.Message)
                If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

                Return "Error"
            }

            Return $webResponse.software
        }
        Else {
            $message = ("{0}: Unable to determine the Uid of the device with ID {1}. To prevent errors, {2} will exit." -f (Get-Date -Format s), $DeviceId, $MyInvocation.MyCommand)
            If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

            Return "Error"
        }
    }
}