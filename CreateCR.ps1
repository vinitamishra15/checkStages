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

# Parseing story/defect IDs
$workItems = $description -split ',' | ForEach-Object { $_.Trim() }

# GitHub repository details
$gitHubToken = $env:GITHUB_TOKEN
$repoUrl = $env:BUILD_REPOSITORY_URI
$repoName = $env:BUILD_REPOSITORY_NAME
$repoOwner = ($repoUrl -split '/')[3]

Write-Host "gitHubToken: $gitHubToken"
Write-Host "repoUrl: $repoUrl and repoName: $repoName and repoOwner: $repoOwner"

if (-not $gitHubToken) {
    Write-Error "GitHub token is not available in GITHUB_TOKEN environment variable."
    exit 1
}

# GitHub API
$gitHubHeaders = @{
    Authorization = "Bearer $gitHubToken"
    Accept        = "application/vnd.github.v3+json"
    "User-Agent"  = "AzurePipelineScript"
}

$commitApiUrl = "https://api.github.com/repos/$repoName/commits?sha=main&per_page=10"
Write-Host "commitApiUrl: $commitApiUrl"
$gitCommits = Invoke-RestMethod -Uri $commitApiUrl -Headers $gitHubHeaders

Write-Host "gitCommits: $gitCommits"

$matchedCommits = @()

foreach ($commit in $gitCommits) {
    $message = $commit.commit.message
    Write-Host "commit: $commit ------ message: $message"
    foreach ($item in $workItems) {
        if ($message -match $item) {
            # Fetch detailed commit (for files)
            $commitDetails = Invoke-RestMethod -Uri $commit.url -Headers $gitHubHeaders
            $files = $commitDetails.files | ForEach-Object { $_.filename } -join ", "
            $commitInfo = @{
                WorkItem = $item
                Message = $message
                Files = $files
                CommitURL = $commit.html_url
            }
            $matchedCommits += $commitInfo
            break
        }
    }
}

# Format commit summary
$commitSummary = ""
if ($matchedCommits.Count -gt 0) {
    $commitSummary += "`n`n--- Commit Details ---"
    foreach ($commit in $matchedCommits) {
        $commitSummary += "`nWorkItem: $($commit.WorkItem)"
        $commitSummary += "`nMessage: $($commit.Message)"
        $commitSummary += "`nFiles: $($commit.Files)"
        $commitSummary += "`nURL: $($commit.CommitURL)`n"
    }
} else {
    $commitSummary += "`n`n--- No matching commits found in main branch ---"
}

# Append commit summary to description
$fullDescription = $description + $commitSummary

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
