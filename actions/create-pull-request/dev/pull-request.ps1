param (
    [Parameter(Mandatory = $false)]$title = "Automated Pull Request",
    [Parameter(Mandatory = $false)]$branch = "automatic-pull-request",
    [Parameter(Mandatory = $false)]$body = "This is an automated pull request",
    [Parameter(Mandatory = $false)]$remote = "origin",  
    [Parameter(Mandatory = $false)]$commitMessage = "Create-Pull-Request commit",
    [Parameter(Mandatory = $false)]$destinationBranch
)



$uniqueUserName = "github-actions-automated-pullrequest-$($branch)"
$currentBranch = (git branch --show-current)
Write-Host "currentbranch: $($currentBranch)"
if ($destinationBranch -eq "Current"){
$destinationBranch = $currentBranch
}
git config --global user.email "github-actions@github.com"
git config --global user.name $uniqueUserName
# Create new local branch 
git checkout -b $branch

Write-Host "The username for this agent is:"
Write-Host $uniqueUserName

# Needs to revision. Only consider from 'remote:' to 'local branch' 
$RemoteShowOrigin = (git remote show origin)            #   |
$ofs = "`n"                                             #   |
$RemoteString = "$RemoteShowOrigin"                     #   |
$ofs = " "                                              #   |
#___________________________________________________________|

Write-Host "String containing remote branches"
Write-Output $RemoteString

$remoteBranch = "$($remote)/$($branch)"
try{
    git fetch $remote $destinationBranch
}
catch{
    write-host($_)
}
if(!($RemoteString -like "*$destinationBranch*")){
    throw ("Destination Branch '$destinationBranch' is not in remote.")
    exit
}
# Check if branch with name $branch is in remote 
if ($RemoteString -like "*$branch*") {
    # Fetching and getting last commit information. 
    write-host "Branch is present in remote"
    git fetch $remote $branch
    write-host "Fetched remote branch"
    $lastAuthor = (git log -n 1 "$($remoteBranch)")[1]
    write-host "Last author:"
    Write-Host $lastAuthor
    # Last commit needs to be created by 'github-actions-automated-pullrequest-$($branch)' in order to force push to this branch
    if (!($lastAuthor -like "*$($uniqueUserName)*")) {
        Write-host "Last commit was not created by '$($uniqueUserName)'"
        Write-host "Branch needs to be created by this action."
        throw ("Last commit was not created by '$($uniqueUserName)'`nBranch needs to be created by this action.")
        exit
    }
    # Branch that is present in remote and has correct last author is expected to have a pull request history.
    $PRstate = (gh pr view $branch)[1]
}
else {
    # If new branch needs to be created, there is no pull request history.
    $PRstate = "NONEXISTENT"
    Write-Host "There is no remote branch named $($branch)"
}
# Adding changes
git add .

git commit -m $commitMessage

$isDiff = (git diff "$($remote)/$($destinationBranch)")
if ($null -eq $isDiff) {
    write-host "There is no changes. Exiting Create-Pull-Request action.."
    exit
}
# Pushing - set upstream to remote 
git push --set-upstream $remote $branch -f
# IMORTANT: Writing over current remote branch. The branch will have no commit history.
git push --force

if ($PRstate -ne "NONEXISTENT"){
    try{
        $PRstate = (gh pr view $branch)[1]
    }
    catch{
        Write-Host "The last pull request was deleted."
        $PRstate = "NONEXISTENT"
    }
}
Write-Host "The current pull-request has $($PRstate)"
# What state is the last pull request in?
if ($PRstate -like "*CLOSED*" -or $PRstate -like "*MERGED*" -or $PRstate -like "*NONEXISTENT*") {
    # if pull request is not active, create new Pull Request
    gh pr create --base $destinationBranch --head $branch --title $title --body $body
}
else {
    # if pull request is active (open or draft)

    write-host "A pull Request is already Open or in Draft from '$($remote)/$($branch)' to '$($remote)/$($destinationBranch)'."

}
  