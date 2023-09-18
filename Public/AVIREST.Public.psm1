# Public
Function Connect-AVIRest {
    [CmdletBinding(DefaultParameterSetName = 'Username')]
    Param (
        [Parameter(
            Mandatory=$true,
            Position=0)]
        [Parameter(ParameterSetName = 'Username')]
        [Parameter(ParameterSetName = 'Credential')]
        [ValidateNotNullOrEmpty()]
        [string]$Server,
        [Parameter(
            Mandatory=$true,
            ParameterSetName = 'Username')]
        [ValidateNotNullOrEmpty()]
        [string]$Username,
        [Parameter(
            Mandatory=$true,
            ParameterSetName = 'Username')]
        [ValidateNotNullOrEmpty()]
        [Securestring]$Password,
        [Parameter(
            Mandatory=$true,
            Position=1,
            ParameterSetName = 'Credential')]
        [ValidateNotNullOrEmpty()]
        [PSCredential]$Credential
    )
    # DynamicParam {
    #     $RuntimeDefList = [List[RuntimeDefinedParameter]]::New()
    #     $paramConfig = [DynamicParameterConfig]::New('APIRev', [string[]], $true)
    #     $runtimeParamConfig = @{
    #         ParameterSetName = 'Username','Credential'
    #         DynamicParameterConfig = $paramConfig
    #         StringArgumentCompleter = $global:AVIapiRevsionList
    #     }
    #     $RuntimeDefList.Add((New-RuntimeDefinedParameter @runtimeParamConfig))
    #     $RuntimeDefList | Out-RuntimeDefinedParameterDict
    # }
    Process {
        $global:AVIStdParams = Invoke-AVIRestParameters
        $global:AVISessionParam = [hashtable]::Synchronized(@{
            WebSession = $null
        })
        Switch ($PSCmdlet.ParameterSetName) {
            'Credential' {
                $Username = $Credential.UserName
                [string]$pswd = $Credential.GetNetworkCredential().Password
            }
            'Username' {
                [string]$pswd = $Password | ConvertFrom-SecureString $Password -AsPlainText
            }
        }
        $Body = @{
            'username' = $Username # case sensitive property !!!!!!!!!
            'password' = $pswd # case sensitive property !!!!!!!!!!!!
        }
        $global:AVILbServerInfo = Get-AVIRestToken -Server $Server -Body $Body -APIRev $APIRev
        $global:AVILbServerInfo
    }
}
Function Disconnect-AVIRest {
    $endpoint = "/logout"
    $method = 'POST'
    Invoke-AVIRest -Method $method -Endpoint $endpoint -EA SilentlyContinue
    $global:AVISessionParam.WebSession = $null
    $global:AVIServer = $null
}
Function Get-AVIRestRef {
    [CmdletBinding(
    DefaultParameterSetName = 'Ref',
    SupportsPaging=$true)]
    Param (
        [Parameter(
            Position=0,
            Mandatory=$true,
            ParameterSetName = 'Ref',
            ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [pscustomobject]$AviLbObject,
        [Switch]$RefOnly
    )
    $refList = $AviLbObject | Get-Member -MemberType NoteProperty | Where Name -match '_ref(s)*$' | Select -ExpandProperty Name
    If ($null -eq $refList) {return $Object}
    # $refProperty = $refList[0]
    $propertyList = [List[string]]::New($refList.count)
    :refList foreach ($refProperty in $refList) {
        $refUrl = $AviLbObject.$refProperty
        $splat = @{
            Method = 'GET'
            Endpoint = ($refUrl -split '(/api)' | Select -Skip 1) -join ''
        }
        $refReply = $null
        $refReply = Invoke-AVIRest @splat
        if ($null -eq $refReply -or $null -ne $refReply.API_ErrorMesg) {
            continue refList
        }
        $propertyName = $null
        $propertyName = $refProperty -replace '_ref'
        $propertyList.Add($propertyName)
        $AviLbObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $refReply -Force
    }
    if ($PSBoundParameters.RefOnly.isPresent) {
        # $joinProperty = $propertyList -join ','
        $AviLbObject | Select $propertyList | Foreach {$_.PSObject.TypeNames.Insert(0,'AVIRestRef')}
    }
    else {
        $AviLbObject | Foreach {$_.PSObject.TypeNames.Insert(0,'AVIRestRef')}
    }
}
Function Get-AVIRestRefObject {
    [CmdletBinding(
    DefaultParameterSetName = 'Ref',
    SupportsPaging=$true)]
    Param (
        [Parameter(
            Mandatory=$true,
            Position=0,
            ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [PSTypeName('AVIRestRef')]$Ref,
        [Switch]$RefOnly
    )
    $refList = $AviLbObject | Get-Member -MemberType NoteProperty | Where Name -match '_ref(s)*$' | Select -ExpandProperty Name
    If ($null -eq $refList) {return $Object}
    # $refProperty = $refList[0]
    $propertyList = [List[string]]::New($refList.count)
    :refList foreach ($refProperty in $refList) {
        $refUrl = $AviLbObject.$refProperty
        $splat = @{
            Method = 'GET'
            Endpoint = ($refUrl -split '(/api)' | Select -Skip 1) -join ''
        }
        $refReply = $null
        $refReply = Invoke-AVIRest @splat
        if ($null -eq $refReply -or $null -ne $refReply.API_ErrorMesg) {
            continue refList
        }
        $propertyName = $null
        $propertyName = $refProperty -replace '_ref'
        $propertyList.Add($propertyName)
        $AviLbObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $refReply -Force
    }
    if ($PSBoundParameters.RefOnly.isPresent) {
        # $joinProperty = $propertyList -join ','
        $AviLbObject | Select $propertyList
    }
    else {
        $AviLbObject
    }
}
Function Copy-AVIRestObject {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param(
        [Parameter(
            Position = 0,
            Mandatory=$true,
            ValueFromPipeline=$false,
            ParameterSetName = 'Default')]
        [ValidateNotNullOrEmpty()]
        $InputObject
    )
    DynamicParam {
        $RuntimeDefList = [List[RuntimeDefinedParameter]]::New()
        $paramConfig = [DynamicParameterConfig]::New('Excludes', [string[]], $false)
        [string[]]$completionList = $InputObject | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name -EA SilentlyContinue
        $runtimeParamConfig = @{
            ParameterSetName = 'Default'
            DynamicParameterConfig = $paramConfig
            StringArgumentCompleter = $completionList ? $completionList : ''
        }
        $RuntimeDefList.Add((New-RuntimeDefinedParameter @runtimeParamConfig))
        $RuntimeDefList | Out-RuntimeDefinedParameterDict
    }
    Begin {
    }
    Process {
        $defaultExcludes = 'uuid','url','_last_modified'
        [string[]]$excludeProperty = $defaultExcludes + $Excludes
        $psTypeName = $InputObject.{pstypenames}?[0]
        $result = $InputObject | Select-Object * -ExcludeProperty $excludeProperty -EA SilentlyContinue
        If ($null -ne $InputObject.Name) {
            $result.name = $InputObject.Name + '-Cloned'
        }
        If ($null -ne $psTypeName) {
            $result.PSObject.TypeNames.Insert(0,$psTypeName)
        }
        $result
    }
}
