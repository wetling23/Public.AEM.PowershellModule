Function Get-AemSoftwareList {
    <#
        .DESCRIPTION
            Accepts a device UID and returns a list of installed applications.
        .NOTES
            V1.0.0.0 date: 17 August 2018
                - Initial release.
            V1.0.0.1 date: 23 August 2018
                - Updated output.
                - Fixed bug in setting up the web request parameters.
        .PARAMETER AemAccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER DeviceId
            Device to get the software list for, by id. 
        .PARAMETER DeviceUID
            Device to get the software list for, by uid.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            Get-AemSoftwareList -DeviceUid $uid -AemAccessToken $token
            Get the list of software for the agent specified by the uid.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
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

        $message = ("{0}: Operating in {1}." -f (Get-Date -Format s), $PsCmdlet.ParameterSetName)
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
                $message = ("{0}: Attempting to retrieve the UID of device {1}." -f (Get-Date -Format s), $DeviceId)
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

                $DeviceUId = (Get-AemDevices -DeviceId $DeviceId @deviceQueryParams).Uid
            }
        }

        If ($DeviceUId) {
            $message = ("{0}: Found {1}." -f (Get-Date -Format s), $DeviceUid)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/audit/device/$DeviceUid/software"
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
            }

            $message = ("{0}: Getting installed applications." -f (Get-Date -Format s))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            Try {
                $webResponse = Invoke-WebRequest -UseBasicParsing @params -ErrorAction Stop | ConvertFrom-Json
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
} #1.0.0.0
