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
    [String] [Parameter(Mandatory = $true)] $removeComments,
    [String] [Parameter(Mandatory = $true)] $queryTimeout
)

Add-PSSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
Add-PSSnapin SqlServerProviderSnapin100 -ErrorAction SilentlyContinue

Try {
    Write-Host "Running scripts";

    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=tcp:$serverName.database.windows.net,1433;Initial Catalog=$databaseName;Persist Security Info=False;User ID=$userName;Password=$userPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message -ForegroundColor DarkBlue} 
    $SqlConnection.add_InfoMessage($handler) 
    $SqlConnection.FireInfoMessageEventOnUserErrors = $true
    $SqlConnection.Open()
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.Connection = $SqlConnection
    $SqlCmd.CommandTimeout = $queryTimeout

    Write-Host "Running all scripts in $pathToScripts";

    foreach ($sqlScript in Get-ChildItem -path "$pathToScripts" -Filter *.sql | sort-object) {	
        Write-Host "Running Script " $sqlScript.Name
		
        #Execute the query
        switch ($removeComments) {
        $true {
            (Get-Content $sqlScript.FullName | Out-String) -replace '(?s)/\*.*?\*/', " " -split '\r?\ngo\r?\n' -notmatch '^\s*$' |
                ForEach-Object { $SqlCmd.CommandText = $_.Trim(); $reader = $SqlCmd.ExecuteNonQuery() }
        }
        $false {
            (Get-Content $sqlScript.FullName | Out-String) -split '\r?\ngo\r?\n' |
                ForEach-Object { $SqlCmd.CommandText = $_.Trim(); $reader = $SqlCmd.ExecuteNonQuery() }
        }
    }

    }


    $SqlConnection.Close()
    Write-Host "Finished";
}

Catch {
    Write-Host "Error running SQL script: $_" -ForegroundColor Red
    throw $_
}


