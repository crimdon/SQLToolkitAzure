[CmdletBinding(DefaultParameterSetName = 'None')]
Param
(
	[String] [Parameter(Mandatory = $true)] $ConnectedServiceNameSelector,
	[String] $ConnectedServiceName,
	[String] $ConnectedServiceNameARM,
	[String] [Parameter(Mandatory = $true)] $sqlScript,
	[String] [Parameter(Mandatory = $true)] $serverName,
	[String] [Parameter(Mandatory = $true)] $databaseName,
	[String] [Parameter(Mandatory = $true)] $userName,
	[String] [Parameter(Mandatory = $true)] $userPassword,
	[int] [Parameter(Mandatory = $true)] $queryTimeout
)

Add-PSSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
Add-PSSnapin SqlServerProviderSnapin100 -ErrorAction SilentlyContinue

Write-Host "Running Script"

#Get resource group name
$resources = Find-AzureRmResource -ResourceNameContains $serverName
[string]$resourcegroupname = $resources.ResourceGroupName[0]

#Create Firewall rule
$ipAddress = (Invoke-WebRequest 'http://myexternalip.com/raw' -UseBasicParsing).Content -replace "`n"
if ($ConnectedServiceNameSelected -eq "Azure Resource Manager")
{
    New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourcegroupname -ServerName $serverName -FirewallRuleName 'TFSAgent' -StartIpAddress $ipAddress -EndIpAddress $ipAddress -ErrorAction SilentlyContinue
}
else
{
    New-AzureSqlDatabaseServerFirewallRule -ServerName $serverName -RuleName 'TFSAgent' -StartIpAddress $ipAddress -EndIpAddress $ipAddress -ErrorAction SilentlyContinue
}
	
#Execute the query
$Query = [IO.File]::ReadAllText("$sqlScript")
$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server=tcp:$serverName.database.windows.net,1433;Initial Catalog=$databaseName;Persist Security Info=False;User ID=$userName;Password=$userPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
$SqlConnection.Open()
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = $Query
$SqlCmd.Connection = $SqlConnection
$SqlCmd.CommandTimeout = $queryTimeout
$reader = $SqlCmd.ExecuteReader()
$SqlConnection.Close()
#Invoke-Sqlcmd -ServerInstance "$serverName.database.windows.net" -Database $databaseName -InputFile $sqlScript -Username $userName -Password $userPassword

#Remove Firewall rule
if ($ConnectedServiceNameSelected -eq "Azure Resource Manager")
{
    Remove-AzureRmSqlServerFirewallRule -ResourceGroupName $resourcegroupname -ServerName $servername -FirewallRuleName 'TFSAgent' -Force
}
else
{
    Remove-AzureSqlDatabaseServerFirewallRule -ResourceGroupName -ServerName $servername -RuleName 'TFSAgent' -Force 
}


Write-Host "Finished"




