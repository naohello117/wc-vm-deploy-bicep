# PowerShell DSC Configuration for IIS Web Server
# This script configures IIS and deploys web content to Azure VM from Blob Storage

Configuration ConfigureIIS
{
    param
    (
        [Parameter(Mandatory = $false)]
        [string]$MachineName = 'localhost',
        
        [Parameter(Mandatory = $false)]
        [string]$BlobStorageUrl = ''
    )

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    Node $MachineName
    {
        # Ensure IIS is installed
        WindowsFeature IIS
        {
            Ensure = 'Present'
            Name   = 'Web-Server'
        }

        # Ensure IIS Management Tools are installed
        WindowsFeature IISManagementTools
        {
            Ensure    = 'Present'
            Name      = 'Web-Mgmt-Tools'
            DependsOn = '[WindowsFeature]IIS'
        }

        # Ensure ASP.NET 4.5 is installed
        WindowsFeature ASPNET45
        {
            Ensure    = 'Present'
            Name      = 'Web-Asp-Net45'
            DependsOn = '[WindowsFeature]IIS'
        }

        # Ensure the default website directory exists
        File WebsiteDirectory
        {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = 'C:\inetpub\wwwroot'
            DependsOn       = '[WindowsFeature]IIS'
        }

        # Download and copy index.html from Blob Storage
        Script DownloadIndexHtml
        {
            GetScript  = {
                @{ Result = (Test-Path 'C:\inetpub\wwwroot\index.html') }
            }
            TestScript = {
                Test-Path 'C:\inetpub\wwwroot\index.html'
            }
            SetScript  = {
                $blobUrl = $using:BlobStorageUrl
                if ($blobUrl) {
                    Invoke-WebRequest -Uri "$blobUrl/index.html" -OutFile 'C:\inetpub\wwwroot\index.html' -UseBasicParsing
                }
            }
            DependsOn  = '[File]WebsiteDirectory'
        }

        # Download and copy style.css from Blob Storage
        Script DownloadStyleCss
        {
            GetScript  = {
                @{ Result = (Test-Path 'C:\inetpub\wwwroot\style.css') }
            }
            TestScript = {
                Test-Path 'C:\inetpub\wwwroot\style.css'
            }
            SetScript  = {
                $blobUrl = $using:BlobStorageUrl
                if ($blobUrl) {
                    Invoke-WebRequest -Uri "$blobUrl/style.css" -OutFile 'C:\inetpub\wwwroot\style.css' -UseBasicParsing
                }
            }
            DependsOn  = '[File]WebsiteDirectory'
        }
    }
}

# Note: This configuration will be compiled and packaged on the local machine,
# then deployed to Azure VM via DSC Extension
