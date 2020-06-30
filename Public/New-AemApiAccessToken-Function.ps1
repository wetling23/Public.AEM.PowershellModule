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
            V1.0.0.3 date: 27 October 2018 - by Konstantin Kaminskiy
                - Adjusted returned data to include only the access token itself to increase ease of use.
            V1.0.0.4 date: 16 October 2019
            V1.0.0.5 date: 5 December 2019
            V1.0.0.6 date: 30 June 2020
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER ApiKey
            Mandatory parameter. Represents the API key to AEM's REST API.
        .PARAMETER ApiSecretKey
            Mandatory parameter. Represents the API secret key to AEM's REST API.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            .\New-AemApiAccessToken -ApiKey XXXXXXXXXXXXXXXXXXXX -ApiSecretKey XXXXXXXXXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force
        .EXAMPLE
            $token = New-AemApiAccessToken -ApiKey XXXXXXXXXXXXXXXXXXXX -ApiSecretKey XXXXXXXXXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force
            Store your token in a variable for later use and re-use.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [string]$ApiKey,

        [Parameter(Mandatory = $True)]
        [securestring]$ApiSecretKey,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )
    #requires -Version 3.0

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

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
        Body        = 'grant_type=password&username={0}&password={1}' -f $ApiKey, [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiSecretKey))
    }

    $message = ("{0}: Requesting a bearer token from AutoTask." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

    # Request access token.
    Try {
        $webResponse = Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop | Select-Object -ExpandProperty access_token
    }
    Catch {
        $message = ("{0}: Unexpected error generating an authorization token. To prevent errors, {1} will exit. The specific error message is: {2}" `
                -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

        Return "Error"
    }

    If ($webResponse) {
        $webResponse
    }
    Else {
        Return "Error"
    }
} #1.0.0.6