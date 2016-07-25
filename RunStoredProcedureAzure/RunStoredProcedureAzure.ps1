﻿[CmdletBinding(DefaultParameterSetName = 'None')]
Param
(
	[String] [Parameter(Mandatory = $true)] $ConnectedServiceNameSelector,
	[String] $ConnectedServiceName,
	[String] $ConnectedServiceNameARM,
	[String] [Parameter(Mandatory = $true)] $serverName,
	[String] [Parameter(Mandatory = $true)] $databaseName,
	[String] [Parameter(Mandatory = $true)] $sprocName,
	[String] [Parameter(Mandatory = $true)] $sprocParameters,
	[String] [Parameter(Mandatory = $true)] $userName,
	[String] [Parameter(Mandatory = $true)] $userPassword
)

Add-PSSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
Add-PSSnapin SqlServerProviderSnapin100 -ErrorAction SilentlyContinue

Write-Host "Running Stored Procedure"

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
    New-AzureSqlServerFirewallRule -ServerName $serverName -RuleName 'TFSAgent' -StartIpAddress $ipAddress -EndIpAddress $ipAddress -ErrorAction SilentlyContinue
}

#Construct to the SQL to run
[string]$sqlQuery = "EXEC " + $sprocName + " " + $sprocParameters
	
#Execute the query
$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server=tcp:$serverName.database.windows.net,1433;Initial Catalog=$databaseName;Persist Security Info=False;User ID=$userName;Password=$userPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
$SqlConnection.Open()
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = $Query
$SqlCmd.Connection = $SqlConnection
$reader = $SqlCmd.ExecuteReader()
#Invoke-Sqlcmd -ServerInstance "$serverName.database.windows.net" -Database $databaseName -Query $sqlQuery -Username $userName -Password $userPassword

#Remove Firewall rule
if ($ConnectedServiceNameSelected -eq "Azure Resource Manager")
{
    Remove-AzureRmSqlServerFirewallRule -ResourceGroupName $resourcegroupname -ServerName $servername -FirewallRuleName 'TFSAgent' -Force
}
else
{
    Remove-AzureSqlServerFirewallRule -ResourceGroupName -ServerName $servername -RuleName 'TFSAgent' -Force 
}

Write-Host "Finished"

