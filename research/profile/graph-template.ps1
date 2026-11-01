# Trusted packaged graph bytes, with only the Windows ESP GUID data personalized.
# No compilation, device query, staging or boot in this module.
function New-PinnedGraphFromTemplate([string]$Repo,[guid]$WindowsGuid,[string]$Output){
 $sentinel=[guid]'a2b4c6d8-1357-49ab-bcde-102030405060'
 if($WindowsGuid -eq [guid]::Empty -or $WindowsGuid -eq $sentinel){throw 'Invalid Windows ESP pin; do not stage.'}
 $base=Join-Path $Repo 'research/profile/graph-template'
 $mp=Join-Path $base 'template.json';$tp=Join-Path $base 'graph-only.template'
 if((Get-GraphHash $mp) -cne '26f24097a9f73667f2101ec7ac5d72cb4baa417808097e3e24c509fe8fbca9a4' -or
    (Get-GraphHash $tp) -cne '7070d624c00cb4d194ae03626f336ae0b02b279716ffb42f6b53cf5609c5ee60'){throw 'Packaged graph template identity changed; stop.'}
 $m=Get-Content -LiteralPath $mp -Raw|ConvertFrom-Json
 foreach($row in $m.Sources){
  if($row.Path -cnotmatch '^(internal-boot|deps/edk2/MdePkg/Include)/[A-Za-z0-9_./-]+$' -or $row.Path.Contains('..')){throw 'Invalid source pin.'}
  if((Get-GraphHash (Join-Path $Repo $row.Path)) -cne $row.Sha256){throw 'Packaged graph source pin changed; stop without building or staging.'}
 }
 $bytes=[IO.File]::ReadAllBytes($tp);$pin=$WindowsGuid.ToByteArray();$expected=$sentinel.ToByteArray()
 if($bytes.Length -ne 14848 -or $m.GuidOffset -ne 10752){throw 'Unexpected template layout.'}
 # Exact immutable template hash already pins code, PE metadata and the data offset.
 for($i=0;$i -lt 16;$i++){
  if($bytes[10752+$i] -ne $expected[$i]){throw 'Unexpected template GUID data.'}
  $bytes[10752+$i]=$pin[$i]
 }
 if(Test-Path -LiteralPath $Output){throw 'Output already exists; preserve it. No automatic retry.'}
 New-Item -ItemType Directory -Path $Output|Out-Null
 $image=Join-Path $Output 'GRAPH-ONLY.EFI';[IO.File]::WriteAllBytes($image,$bytes)
 $hash=Get-GraphHash $image
 [ordered]@{Mode='graph-only-build';FixtureOnly=$false;Personalization='windows-esp-guid-data-only';BuildPerformed=$false;
  HardwareTested=$false;CanUnlock=$false;CanDetach=$false;ReadsGpuMmio=$false;DumpsProm=$false;DumpsImages=$false;
  WritesFirmwareVariables=$false;EfiSha256=$hash;TemplateSha256=$m.TemplateSha256;SourceInputCount=@($m.Sources).Count} |
  ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $Output 'manifest.json') -Encoding utf8
 return $Output
}
