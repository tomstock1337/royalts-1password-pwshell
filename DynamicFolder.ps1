# ---------------------------------------------------------------------------------------------------------------------
# Note that the whole output of the script will be parsed as rJSON and should be UTF8 encoded
# The following lines ensure that informational cmdlet output, warnings or errors are not written to the output stream
# ---------------------------------------------------------------------------------------------------------------------
$global:ErrorActionPreference = "Stop"
$global:WarningPreference = "SilentlyContinue"
$global:InformationPreference = "SilentlyContinue"
$global:VerbosePreference = "SilentlyContinue"
$global:DebugPreference = "SilentlyContinue"
$global:ProgressPreference = "SilentlyContinue"
$global:OutputEncoding = New-Object Text.Utf8Encoding -ArgumentList (,$false) # BOM-less
[Console]::OutputEncoding = $global:OutputEncoding

$tagDelimitedList = '$CustomProperty.TagFilterList$'

# Check if 'op' is available in PATH
if (-not (Get-Command "op" -ErrorAction SilentlyContinue)) {
    Write-Error "'op' (1Password CLI) is not found in your PATH. Please install it and ensure it is accessible."
    exit 1
}
function Run1PasswordCommand() {
    param (
        [string]$command
    )

    $tagCommand = ""

    try {
        # Check if $tagDelimitedList is null or empty
        if ($tagDelimitedList -ne '$'+'CustomProperty.TagFilterList'+'$' -and $tagDelimitedList -ne '' -and $command -like "item list*") {
            $tagCommand = "--tags $($tagDelimitedList)"
            $command = "$command $tagCommand"
        }
        $args = $command -split ' '
        # Execute the command and capture output
        $output = op @args 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Command 'op $command' failed. Error: $output"
            exit 2
        }
        return $output
    }
    catch {
        Write-Error "An unexpected error occurred while executing 'op $command': $($_.Exception.Message)"
        exit 99
    }
}

Run1PasswordCommand 'signin'

# Create a hashtable representing your data
$foldersForRoyal = [System.Collections.ArrayList]::new()

$accountsJson = Run1PasswordCommand 'account list --format json'
$accounts = $accountsJson | ConvertFrom-Json

foreach ($account in $accounts) {
  $accountObj = @{}
  $accountObj.add("Name", $account.email)
  $accountObj.add("Type", 'Folder')

  $vaultsJson = Run1PasswordCommand "vault list --account $($account.account_uuid) --format json"
  $vaults = $vaultsJson | ConvertFrom-Json
  $vaultList = [System.Collections.ArrayList]::new()
  foreach($vault in $vaults) {
    $vaultObj = @{}
    $vaultObj.add("Name", $vault.name)
    $vaultObj.add("Type", 'Folder')

    $credentialsJson = Run1PasswordCommand "item list --account $($account.account_uuid) --vault $($vault.id) --format json"
    $credentials = $credentialsJson | ConvertFrom-Json
    $credentialList = [System.Collections.ArrayList]::new()
    foreach($credential in $credentials) {
      $credentialItemJson = Run1PasswordCommand "item get $($credential.id) --account $($account.account_uuid) --vault $($vault.id) --format json"
      $credentialItem = $credentialItemJson | ConvertFrom-Json

      $credentialObj = @{}
      $credentialObj.add("Name", $credential.title)
      $credentialObj.add("Type", 'Credential')
      $credentialObj.add("ID", $credential.id)
      $credentialObj.add("Username", ( $credentialItem.fields | Where-Object { $_.id -eq 'username' } | Select-Object -ExpandProperty value))
      $credentialObj.add("Password", ( $credentialItem.fields | Where-Object { $_.id -eq 'password' } | Select-Object -ExpandProperty value))

      $credentialList.add($credentialObj) | Out-Null
    }
    $vaultObj.add("Objects", @($credentialList)) | Out-Null

    $vaultList.add($vaultObj) | Out-Null
  }

  $accountObj.add("Objects", @($vaultList)) | Out-Null

  $foldersForRoyal.add($accountObj) | Out-Null
}
$hash = @{ }
$hash.add("Objects", $foldersForRoyal) | Out-Null
$hash | ConvertTo-Json -Depth 100