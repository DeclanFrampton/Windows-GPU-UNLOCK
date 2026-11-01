# Shared launcher; machine IDs select exact reviewed preparation pins only.
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('issue33','issue109','issue31','issue180')][string]$Machine,
      [ValidatePattern('^[D-Zd-z]$')][string]$Drive,[switch]$Collect,
      [string]$Clang='clang',[string]$LldLink='lld-link',[string]$Python='python')
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'prepare-x99-graph.ps1') @PSBoundParameters
if(!$?){exit 1}
