[CmdletBinding(DefaultParameterSetName = 'None')]
Param
(
    [String] [Parameter(Mandatory = $true)] $ConnectedServiceNameSelector,
    [String] $ConnectedServiceName,
    [String] $ConnectedServiceNameARM,
    [String] [Parameter(Mandatory = $true)] $pathToScripts,
    [String] [Parameter(Mandatory = $true)] $executionOrder
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
    $scripts = Get-ChildItem -path "$pathToScripts" -Filter *.sql | sort-object

    if ([string]::IsNullOrEmpty($executionOrder)) {
        Write-Host "Running all scripts in $pathToScripts";
        foreach ($sqlScript in [System.Linq.Enumerable]::OrderBy($scripts, [Func[object, int]] { param($x) [int]($x.Name -replace '(\d+)_(.*)', '$1') })
        ) {	
            Write-Host "Running Script " $sqlScript.Name
		
            #Execute the query
            switch ($removeComments) {
                $true {
                    (Get-Content $sqlScript.FullName | Out-String) -replace '(?s)/\*.*?\*/', " " -split '\r?\n\s*go\r?\n' -notmatch '^\s*$' |
                        ForEach-Object { $SqlCmd.CommandText = $_.Trim(); $reader = $SqlCmd.ExecuteNonQuery() }
                }
                $false {
                    (Get-Content $sqlScript.FullName | Out-String) -split '\r?\n\s*go\r?\n' |
                        ForEach-Object { $SqlCmd.CommandText = $_.Trim(); $reader = $SqlCmd.ExecuteNonQuery() }
                }
            }
        }
        else {
            Write-Host "Using file $executionOrder"
            $TOCFile = $pathToScripts + "\" + $executionOrder
            Write-Host "Using file $TOCFile"
            Get-Content $TOCFile -Encoding UTF8 | ForEach-Object {
                $sqlScript = $pathToScripts + "\" + $_
                Write-Host "Running Script " $sqlScript
                #Execute the query
                switch ($removeComments) {
                    $true {
                        (Get-Content $sqlScript.FullName | Out-String) -replace '(?s)/\*.*?\*/', " " -split '\r?\n\s*go\r?\n' -notmatch '^\s*$' |
                            ForEach-Object { $SqlCmd.CommandText = $_.Trim(); $reader = $SqlCmd.ExecuteNonQuery() }
                    }
                    $false {
                        (Get-Content $sqlScript.FullName | Out-String) -split '\r?\n\s*go\r?\n' |
                            ForEach-Object { $SqlCmd.CommandText = $_.Trim(); $reader = $SqlCmd.ExecuteNonQuery() }
                    }
                }
            }
        }


        $SqlConnection.Close()
        Write-Host "Finished";
    }
}

    Catch {
        Write-Host "Error running SQL script: $_" -ForegroundColor Red
        throw $_
    }


