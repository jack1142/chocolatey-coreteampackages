Import-Module AU
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"

$releases = 'https://www.spotify.com/en/download/windows/'
$padUnderVersion = '1.1.8'

function global:au_SearchReplace {
  return @{
    ".\tools\chocolateyInstall.ps1" = @{
      "(?i)(^\s*url\s*=\s*)('.*')"          = "`$1'$($Latest.URL32)'"
      "(?i)(^\s*checksum\s*=\s*)('.*')"     = "`$1'$($Latest.Checksum32)'"
      "(?i)(^\s*checksumType\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType32)'"
    }
  }
}

function global:au_AfterUpdate {
  "$($Latest.ETAG)|$($Latest.Version)" | Out-File "$PSScriptRoot\info" -Encoding utf8
}

function GetResultInformation([string]$url32) {
  $dest = "$env:TEMP\spotify.exe"
  Get-WebFile $url32 $dest | Out-Null
  $version = Get-Item $dest | % { $_.VersionInfo.ProductVersion -replace '^([\d]+(\.[\d]+){1,3}).*', '$1' }

  $result = @{
    URL32          = $url32
    Version        = Get-FixVersion -Version $version -OnlyFixBelowVersion $padUnderVersion
    Checksum32     = Get-FileHash $dest -Algorithm SHA512 | % Hash
    ChecksumType32 = 'sha512'
  }
  Remove-Item -Force $dest
  return $result
}

function GetETagIfChanged() {
  param([string]$uri)
  if (($global:au_Force -ne $true) -and (Test-Path $PSScriptRoot\info)) {
    $existingETag = $etag = Get-Content "$PSScriptRoot\info" -Encoding UTF8 | select -First 1 | % { $_ -split '\|' } | select -first 1
  }
  else { $existingETag = $null }

  $etag = Invoke-WebRequest -Method Head -Uri $uri -UseBasicParsing
  $etag = $etag | % { $_.Headers.ETag }
  if ($etag -eq $existingETag) { return $null }

  return $etag
}

function global:au_GetLatest {
  $download_page = Invoke-WebRequest -Uri $releases -UseBasicParsing
  # $downloadUrl = $download_page.Links | ? href -match "\.exe$" | select -first 1 -expand href
  $download_page.Content -match "https://.+?exe" | Out-Null
  $downloadUrl = $Matches[0]
  $etag = GetETagIfChanged -uri $downloadUrl

  if ($etag) {
    $result = GetResultInformation $downloadUrl
    $result["ETAG"] = $etag
  }
  else {
    $result = @{
      URL32   = $downloadUrl
      Version = Get-Content "$PSScriptRoot\info" -Encoding UTF8 | select -First 1 | % { $_ -split '\|' } | select -Last 1
    }
  }

  return $result
}

update -ChecksumFor none
