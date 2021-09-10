# General
Windows PowerShell module for accessing the Datto RMM (formerly AutoTask Endpoint Management) REST API

This project is also published in the PowerShell Gallery at https://www.powershellgallery.com/packages/AutoTaskEndpointManagement.

# Installation
* From PowerShell Gallery: Install-Module -Name AutoTaskEndpointManagement
* From GitHub: Save `/bin/<version>/AutoTaskEndpointManagement/<files>` to your module directory

# Behavior changes
## 1.0.0.27
- Out-PsLogging
  - Prepending [INFO], [WARNING], [ERROR], [VERBOSE] blocks before each message.
## 1.0.0.11
* New behavior in logging. Instead of only logging to the Windows event log, the module now defaults to host only.
* The EventLogSource parameter is still available. If the provided source does not exist, the command will switch to host-only output.
* The new option is the LogPath parameter. Provide a path and file name (e.g. C:\Temp\log.txt) for logging. The module will attempt to create the log file, if it does not exist, and will switch to host-only output, if the file cannot be created (or the desired path is not writable).