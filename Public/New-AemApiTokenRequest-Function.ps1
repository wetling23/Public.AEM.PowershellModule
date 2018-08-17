Function New-AemApiAccessToken {
    <#
        .DESCRIPTION
            Retrieves an authorization token from AutoTask.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 15 June 2018
                - Initial release.
            V1.0.0.1 date: 17 June 2018
                - Added missing closing backet.
            V1.0.0.2 date: 16 August 2018
                - Removed Ssl3 and Tsl protocol support.
                - Added return.
                - Fixed output bug. The -BlockLogging parameter was blocking all output.
                - Updated white space.
        .LINK
        .PARAMETER ApiKey
            Mandatory parameter. Represents the API key to AEM's REST API.
        .PARAMETER ApiSecretKey
                Mandatory parameter. Represents the API secret key to AEM's REST API.
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            .\New-AemApiAccessToken -ApiKey XXXXXXXXXXXXXXXXXXXX -ApiSecretKey XXXXXXXXXXXXXXXXXXXX
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [string]$ApiKey,

        [Parameter(Mandatory = $True)]
        [string]$ApiSecretKey,
        
        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [string]$EventLogSource = 'AemPowerShellModule',

        [switch]$BlockLogging
    )
    #requires -Version 3.0

    If (-NOT($BlockLogging)) {
        $return = Add-EventLogSource -EventLogSource $EventLogSource

        If ($return -ne "Success") {
            $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
            Write-Host $message -ForegroundColor Yellow;

            $BlockLogging = $True
        }
    }

    $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

    # Specify security protocols.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]'Tls11,Tls12'

    # Convert password to secure string.
    $securePassword = ConvertTo-SecureString -String 'public' -AsPlainText -Force

    # Define parameters for Invoke-WebRequest cmdlet.
    $params = @{
        Credential  = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('public-client', $securePassword)
        Uri         = '{0}/auth/oauth/token' -f $ApiUrl
        Method      = 'POST'
        ContentType = 'application/x-www-form-urlencoded'
        Body        = 'grant_type=password&username={0}&password={1}' -f $ApiKey, $ApiSecretKey
    }

    $message = ("{0}: Requesting a bearer token from AutoTask." -f (Get-Date -Format s), $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

    # Request access token.
    Try {
        $webResponse = Invoke-WebRequest @params -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error generating an authorization token. To prevent errors, {1} will exit. The specific error message is: {2}" `
                -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
        If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

        Return "Error"
    }

    If ($webResponse) {
        $webResponse
    }
    Else {
        Return "Error"
    }
} #1.0.0.2