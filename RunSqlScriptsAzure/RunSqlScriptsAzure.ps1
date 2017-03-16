[CmdletBinding(DefaultParameterSetName = 'None')]
Param
(
	[String] [Parameter(Mandatory = $true)] $ConnectedServiceNameSelector,
	[String] $ConnectedServiceName,
	[String] $ConnectedServiceNameARM,
	[String] [Parameter(Mandatory = $true)] $pathToScripts,
	[String] [Parameter(Mandatory = $true)] $serverName,
	[String] [Parameter(Mandatory = $true)] $databaseName,
	[String] [Parameter(Mandatory = $true)] $userName,
	[String] [Parameter(Mandatory = $true)] $userPassword,
	[String] [Parameter(Mandatory = $true)] $queryTimeout
)

Add-PSSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
Add-PSSnapin SqlServerProviderSnapin100 -ErrorAction SilentlyContinue

Try
{
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

	Write-Host "Running scripts";

	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
	$SqlConnection.ConnectionString = "Server=tcp:$serverName.database.windows.net,1433;Initial Catalog=$databaseName;Persist Security Info=False;User ID=$userName;Password=$userPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
	$handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message -ForegroundColor DarkBlue} 
    $SqlConnection.add_InfoMessage($handler) 
	$SqlConnection.FireInfoMessageEventOnUserErrors=$true
	$SqlConnection.Open()
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.Connection = $SqlConnection
	$SqlCmd.CommandTimeout = $queryTimeout

	foreach ($sqlScript in Get-ChildItem -path "$pathToScripts" -Filter *.sql | sort-object)
	{	
		#Execute the query
		$Query = [IO.File]::ReadAllText("$($sqlScript.FullName)")
		$batches = $Query -split "\s*$batchDelimiter\s*\r?\n"
		foreach($batch in $batches)
		{
			if($batch.Trim() -ne "")
			{
				$SqlCmd.CommandText = $batch
				$reader = $SqlCmd.ExecuteNonQuery()
			}
		}
	}

	$SqlConnection.Close()

	#Remove Firewall rule
	if ($ConnectedServiceNameSelected -eq "Azure Resource Manager")
	{
	    Remove-AzureRmSqlServerFirewallRule -ResourceGroupName $resourcegroupname -ServerName $servername -FirewallRuleName 'TFSAgent' -Force -ErrorAction SilentlyContinue
	}
	else
	{
	    Remove-AzureSqlDatabaseServerFirewallRule -ServerName $servername -RuleName 'TFSAgent' -Force  -ErrorAction SilentlyContinue
	}

	Write-Host "Finished";
}

Catch
{
	Write-Host "Error running SQL script: $_" -ForegroundColor Red
	throw $_
}


