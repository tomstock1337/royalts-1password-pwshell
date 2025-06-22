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

$vaultId = '$CustomProperty.VaultId$'
$accountUUID = '$CustomProperty.AccountUUID$'
$credentialID = '$DynamicCredential.EffectiveID$'

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
      $errorMsg = $_.Exception.Message
      if ($errorMsg -match "Could not connect to the 1Password desktop app") {
          Write-Error "Could not connect to the 1Password desktop app. Please ensure it is installed, running, and that CLI integration is enabled."
          exit 3
      } else {
          Write-Error "An unexpected error occurred while executing 'op $command': $errorMsg"
          exit 99
      }
    }
}

$credForRoyal = [System.Collections.ArrayList]::new()
$credJson = Run1PasswordCommand "item get $($credentialID) --format json --account $($accountUUID) --vault $($vaultId)"
$cred = $credJson | ConvertFrom-Json

$credObj = @{}
if ($cred.category -eq "SSH_KEY")
{
  $credObj.add("Username", ( $cred.fields | Where-Object { $_.label -eq 'username' } | Select-Object -ExpandProperty value))
  $credObj.add("Password", ( $cred.fields | Where-Object { $_.label -eq 'password' } | Select-Object -ExpandProperty value))
}
else {
  $credObj.add("Username", ( $cred.fields | Where-Object { $_.id -eq 'username' } | Select-Object -ExpandProperty value))
  $credObj.add("Password", ( $cred.fields | Where-Object { $_.id -eq 'password' } | Select-Object -ExpandProperty value))
}
$credObj | ConvertTo-Json -Depth 100