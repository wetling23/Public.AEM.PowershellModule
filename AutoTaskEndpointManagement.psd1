@{

    # Script module or binary module file associated with this manifest
    RootModule        = 'AutoTaskEndpointManagement.psm1'

    # Version number of this module.
    ModuleVersion     = '2024.08.27.0'

    # ID used to uniquely identify this module
    GUID              = 'b3b16a0a-35f8-4ee9-bd4d-868e8b1dc24a'

    # Author of this module
    Author            = 'Mike Hashemi'

    # Company or vendor of this module
    CompanyName       = ''

    # Copyright statement for this module
    Copyright         = '(c) 2024 mhashemi. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'Powershell module refactoring the AutoTask Endpoint Management REST API.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of the .NET Framework required by this module
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module
    FunctionsToExport = 'Find-AemSoftwareInstance',
    'Get-AemDevicesFromSite', 'Get-AemDevice', 'Get-AemDeviceAudit', 'Get-AemJob', 'Get-AemSite', 'Get-AemSiteVariable', 'Get-AemSite',
    'Get-AemSoftwareList', 'Get-AemUser',
    'New-AemApiAccessToken', 'New-AemSite', 'New-AemSiteVariable',
    'Out-PsLogging',
    'Set-AemDeviceUdf', 'Set-AemSiteDescription', 'Set-AemSiteVariable',
    'Start-AemQuickJob'

    # Cmdlets to export from this module
    CmdletsToExport   = '*'

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport   = '*'

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/wetling23/Public.AEM.PowershellModule'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = 'Updated New-AemSite to 2024.08.27.0.'

            # External dependent modules of this module
            # ExternalModuleDependencies = ''

        } # End of PSData hashtable

    } # End of PrivateData hashtable


    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}