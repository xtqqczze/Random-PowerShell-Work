<#PSScriptInfo

.VERSION 1.6

.GUID b787dc5d-8d11-45e9-aeef-5cf3a1f690de

.AUTHOR Adam Bertram

.COMPANYNAME Adam the Automator, LLC

.TAGS Processes

#>

<# 

.DESCRIPTION 
 	Invoke-Process is a simple wrapper function that aims to "PowerShellyify" launching typical external processes. There
	are lots of ways to invoke processes in PowerShell with Start-Process, Invoke-Expression, & and others but none account
	well for the various streams and exit codes that an external process returns. Also, it's hard to write good tests
	when launching external proceses.

	This function ensures any errors are sent to the error stream, standard output is sent via the Output stream and any
	time the process returns an exit code other than 0, treat it as an error.

#> 

function Invoke-Process {
    [CmdletBinding(
		SupportsShouldProcess = $true
	)]
    param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('PSPath', 'Path')]
        [string]$FilePath,

        [Parameter(
            Mandatory = $false,	
            Position = 1,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('Args', 'Arguments')]
        [string[]]$ArgumentList
    )
	
    begin {
        $savedErrorActionPreference = $ErrorActionPreference
		$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

		function RemoveLastNewLine([string]$text, $nl = [System.Environment]::NewLine)
		{
			if ($text.EndsWith($nl))
			{
				return $text.Remove($text.Length - $nl)
			}
			else {
				return $text
			}
		}
    }

    process {
        try {
            $p = New-Object -TypeName 'System.Diagnostics.Process'
			$p.StartInfo.Filename = $FilePath
			# TODO: Add arguments explicitly
            $p.StartInfo.Arguments = $ArgumentList
            $p.StartInfo.RedirectStandardOutput = $true
            $p.StartInfo.RedirectStandardError = $true
            $p.StartInfo.UseShellExecute = $false
			$p.StartInfo.CreateNoWindow = $true
			
			$target = "`"$($p.StartInfo.Filename)`"" +
			$(if (-not [string]::IsNullOrEmpty($p.StartInfo.Arguments)) {
				' ' + $p.StartInfo.Arguments
			})

            if ($PSCmdlet.ShouldProcess($target, "Invoke-Process")) {
                $p.Start() > $null
				$p.WaitForExit()
				return $p.StandardOutput.ReadToEnd()
                if ($p.ExitCode -eq 0) {
                    if (-not $p.StandardOutput.EndOfStream) {
                        Write-Output -InputObject (RemoveLastNewLine($p.StandardOutput.ReadToEnd()))
                    }
                }
                else {
                    if (-not $p.StandardError.EndOfStream) {
                        throw RemoveLastNewLine($p.StandardError.ReadToEnd())
                    }
                    elseif (-not $p.StandardOutput.EndOfStream) {
                        throw RemoveLastNewLine($p.StandardOutput.ReadToEnd())
                    }
                    else {
                        throw $p.ExitCode
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    end {
        $ErrorActionPreference = $savedErrorActionPreference
    }
}
