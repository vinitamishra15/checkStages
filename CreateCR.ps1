#Create change request for approval
param(
  [string]$SNowInstance,
  [string]$destUName,
  [string]$destPwd,
  [string]$sourceDir
)

#Create body for change request
Write-Host "Source directory is $sourceDir"
$CR_path = "$sourceDir/CR_template.json"
$CR_Data = Get-Content -Raw -Path $CR_path | ConvertFrom-Json

$shortDesc=$CR_data.short_description
$description=$CR_data.description
$category=$CR_data.category
$type=$CR_data.type
$priority=$CR_data.priority
$risk=$CR_data.risk
$impact=$CR_data.impact          
$assignment_group=$CR_data.assignment_group
$justification=$CR_data.justification
$implementation_plan=$CR_data.implementation_plan
$backout_plan=$CR_data.backout_plan

#Create CR using REST API
$url = "https://$SNowInstance.service-now.com/api/now/table/change_request"
$auth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${destUName}:${destPwd}"))
$headers = @{ Authorization = "Basic $auth"; 'Content-Type' = 'application/json' }
$body = @{
  "short_description"   = $shortDesc
  "description"         = $description
  "category"            = $category
  "type"                = $type
  "priority"            = $priority
  "risk"                = $risk
  "impact"              = $impact
  "assignment_group"    = $assignment_group
  "justification"	      = $justification
  "implementation_plan" = $implementation_plan
  "backout_plan"        = $backout_plan
} | ConvertTo-Json -Depth 3

$response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body
$changeRequestSysId = $response.result.sys_id
$ChangeRequestNo = $response.result.number
Write-Host "Created Change Request with sys_id: $changeRequestSysId"
Write-Host "Change request created: $ChangeRequestNo"

# Move CR to "request approval" phase
$updateurl = "https://$SNowInstance.service-now.com/api/now/table/change_request/$changeRequestSysId"
$updateBody = @{
  state = "-4"
} | ConvertTo-Json -Depth 2

Invoke-RestMethod -Uri $updateurl -Method Patch -Headers $headers -Body $updateBody
Write-Host "Change request moved Approval phase"

Write-Host "##vso[task.setvariable variable=changeRequestSysId]$changeRequestSysId"
