using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

Get-Content -Raw .\Private\AVIRest.Private.psm1  | Out-File AVIREST.psm1 -Force
Get-Content -Raw .\Public\AVIRest.Public.psm1  | Out-File AVIREST.psm1 -Append

$dynamicExportList = [List[string]]::New()
$exportFunctionList = [List[string]]::New()
Try {
    # Templates
    $templateFunctionGET = Get-Content .\Templates\GET.pst1 -Raw -EA Stop
    $templateFunctionPUT = Get-Content .\Templates\PUT.pst1 -Raw 
    $templateFunctionDELETE = Get-Content .\Templates\DELETE.pst1 -Raw 
    $templateFunctionPOST = Get-Content .\Templates\POST.pst1 -Raw
    $templateFunctionPOSTuuid = Get-Content .\Templates\POSTUuid.pst1 -Raw
    $templateObject = Get-Content .\Templates\NEWObj.pst1 -Raw
    $swaggerLocation = '..\Swagger','.\Swagger' | Where {(Test-Path $_) -eq $true}
    $jsonFileList = Get-ChildItem "$swaggerLocation\*.json" -Exclude 'package.json'

    $jsonFileData = $jsonFileList | Foreach {
        Get-Content $_ -Raw | ConvertFrom-JSON -Depth 100 -AsHashtable
    }
    [string[]]$global:AVIapiRevsionList = $jsonFileData | Group {$_.info.version} -NoElement | Select -ExpandProperty Name
    
    # $jsonData = $jsonFileData[0]
    $jsonData = $jsonFileData | Where {$_.info.title -match 'ipaddr'}
    Foreach ($jsonData in $jsonFileData) {
        $title = $jsonData.info.title
        Write-Verbose "Loading swagger endpoint [$title]"
        [string]$apiVersion = $jsonData.info.version
        $keyList = $jsonData.paths.Keys
        $key = $keyList[0]
        $methodList = foreach ($key in $keyList) {
            $methodLookup = $jsonData.paths.$Key
            foreach ($method in $methodLookup.Keys) {
                [pscustomobject]@{
                    Method = $method
                    ApiPath = $key
                }
            }
        }
        $methodLookup = $methodList | Group Method -AsHashTable -AsString

        # Methods
        $get,$put,$delete,$new = $null
        ## Get
        $get = $methodLookup.get
        if ($null -ne $get) {
            $primaryKey,$uuidList,$resourceList,$joinResources = $null
            $primaryKey = $get[0].ApiPath # the primary endpoint
            $uuidList = $get.ApiPath | Where {$_ -match '{uuid}'}
            if ($null -ne $uuidList) {
                $resourceList = $uuidList[1..$uuidList.count] | Foreach {$_ -replace "$primaryKey/{uuid}/|/$"}
            }
            if ($null -ne $resourceList) {
                $joinResources = '{0}' -f ($resourceList -split '\r\n' -join ',')
            }

            $apiPath = $get.ApiPath[0]
            $apiName = Get-ApiPathName $get[0].ApiPath
            $functionGET = $templateFunctionGET -replace '\{0\}',$apiPath -replace '\{1\}',$joinResources -replace '\{2\}',$apiName -replace '\{3\}',$apiVersion -replace '\{4\}',$title
            # Invoke-Expression -Command $functionGET
            $exportName = "Get-AVIRest$apiName"
            $dynamicExportList.Add($exportName)
            $exportFunctionList.Add($functionGET)
        }

        ## PUT
        $putList = $methodLookup.put
        # $put = $putList[0]
        foreach ($put in $putList) {
            $functionTemplate = Get-AVIFunctionTemplate $put $templateFunctionPUT $jsonData
            # Invoke-Expression -Command $functionTemplate
            $apiName = Get-ApiPathName $put.ApiPath
            $exportName = "Set-AVIRest$apiName"
            $dynamicExportList.Add($exportName)
            $exportFunctionList.Add($functionGET)
        }

        ## POST
        $postList = $methodLookup.post
        ### no id POSTs
        $noIdpostList,$noIdpostFunctionList = $null
        $noIdpostList = $postList | Where {$_.ApiPath -notmatch 'uuid'}

        foreach ($post in $noIdpostList) {
            $functionTemplate = Get-AVIFunctionTemplate $post $templateFunctionPOST $jsonData
            # Invoke-Expression -Command $functionTemplate
            $apiName = Get-ApiPathName $post.ApiPath
            $exportName = "New-AVIRest$apiName"
            $dynamicExportList.Add($exportName)
            $exportFunctionList.Add($functionGET)
        }
        # $noIdpostFunctionList = New-AviRestFunctionExport New $noIdpostList $templateFunctionPOST $jsonData $dynamicExportList
        # Foreach ($noIdFunction in $noIdpostFunctionList) {
        #     Invoke-Expression -Command $noIdFunction
        # }
        $noIdpostFunctionParamList = New-AviRestFunctionParamExport $noIdpostList $templateObject $jsonData $dynamicExportList
        Foreach ($noIdFunctionParam in $noIdpostFunctionParamList ) {
            # Invoke-Expression -Command $noIdFunctionParam
        }

        ### Id POSTs
        $idpostList,$idpostFunctionList = $null
        $idpostList = $postList | Where {$_.ApiPath -match 'uuid'}

        foreach ($post in $idpostList) {
            $functionTemplate = Get-AVIFunctionTemplate $post $templateFunctionPOSTuuid $jsonData
            # Invoke-Expression -Command $functionTemplate
            $apiName = Get-ApiPathName $post.ApiPath
            $exportName = "Invoke-AVIRest$apiName"
            $dynamicExportList.Add($exportName)
            $exportFunctionList.Add($functionGET)
        }
        # $idpostFunctionList = New-AviRestFunctionExport Invoke $idpostList $templateFunctionPOSTuuid $jsonData $dynamicExportList
        # Foreach ($idFunction in $idpostFunctionList) {
        #     Invoke-Expression -Command $idFunction
        # }
        $idpostFunctionParamList = New-AviRestFunctionParamExport $idpostList $templateObject $jsonData $dynamicExportList
        Foreach ($idFunctionParam in $idpostFunctionParamList) {
            # Invoke-Expression -Command $idFunctionParam
        }

        ## Delete
        $deleteList = $methodLookup.delete
        foreach ($delete in $deleteList) {
            $functionTemplate = Get-AVIFunctionTemplate $delete $templateFunctionDELETE $jsonData
            # Invoke-Expression -Command $functionTemplate
            $apiName = Get-ApiPathName $delete.ApiPath
            $exportName = "Remove-AVIRest$apiName"
            $dynamicExportList.Add($exportName)
            $exportFunctionList.Add($functionGET)
        }

        # New Obj # this needs work to add body and body-less versions
        # $path,$pathCase = $null
        # $path = $keyList[0] -replace '/'
        # $pathCase = $jsonData.definitions.keys | Where {$_ -eq $path}
        # if ($null -eq $pathCase) {continue}

        # $definitionList = $jsonData.definitions
        # $fullObj = New-AVISwaggerJsonObj -Definitions $definitionList -Path $pathCase
        # $minObj = New-AVISwaggerJsonObj -Definitions $definitionList -Path $pathCase -MinRequired
        # $objectFunction = $templateObject -replace '\{0\}',$pathCase -replace '\{1\}',$minObj -replace '\{2\}',$fullObj -replace '\{3\}',$apiVersion -replace '\{4\}',$title
        # Invoke-Expression -Command $objectFunction
        # $exportName = "New-AVIRest{0}Object" -f $pathCase
        # $dynamicExportList.Add($exportName)
        # $exportFunctionList.Add($functionGET)
    }
}
Catch {
    Throw $error[0]
}
$exportFunctionList | Out-File AVIREST.psm1 -Append

@'
$staticExportList = 'Connect-AVIRest','Disconnect-AVIRest','Get-AVIRestRef','Copy-AVIRestObject'
$exportList = $staticExportList + $dynamicExportList
Export-ModuleMember $exportList 
'@  | Out-File AVIREST.psm1 -Append
