# Set-ExecutionPolicy -ExecutionPolicy Unrestricted

[CmdletBinding()]
param(
    [String]$BuildType,
    [String]$TargetName
)

Write-Host "TargetName: $TargetName"

function getCRC($data) {
    [String]$regex = "^CRC32  for data:\s+(\w+)$"
    $line = ($data | Select -SkipLast 1) -match $regex 
    if (![String]::IsNullOrEmpty($line)) {
        if ($line[0] -match $regex) {
            return $Matches[1]
        }
    }
}

if ($BuildType -eq "Release") {
    # Clean up third-party documentation and debug files
    Get-ChildItem -Name -Include "*.xml", "*.pdb", "*.application", "*.exe.manifest" -Exclude "logger.xml", "$($TargetName).pdb" | Remove-Item;

    $pinFile = "C:\temp\pin.txt"
    if (Test-Path $pinFile) {
        $pin = Get-Content -Path $pinFile
        Set-Clipboard $pin
        Write-Host "PIN: $(Get-Clipboard)"
    } else {
        Write-Host "Create a file containing the PIN in $pinFile"
    }

    & '..\..\..\..\src\packages\squirrel.windows.1.9.0\tools\signtool.exe' sign /a /n "Paul Woolcock" /tr http://time.certum.pl/ /td sha256 /fd sha256 /v "$($TargetName).exe"
    
    $version = (Get-Item "$($TargetName).exe").VersionInfo.FileVersion
    if ($version -notmatch "\.0$") {
        $zipFile = "v$version.zip"
        & 'C:\Program Files\7-Zip\7z.exe' a $zipFile "$($TargetName).exe" "$($TargetName).pdb"
        Copy-Item $zipFile Z:\

        $output = & 'C:\Program Files\7-Zip\7z.exe' h $zipFile
        $zipCRC = getCRC $output
        $output = & 'C:\Program Files\7-Zip\7z.exe' t $zipFile -scrc "$($TargetName).exe"
        $exeCRC = getCRC $output

        Set-Clipboard "Zip = ``$zipCRC`` Exe = ``$exeCrc``"
        Write-Host (Get-Clipboard)
    }
}
