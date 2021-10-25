# Create Pull Request

## Description

This action will move changes form the checked out branch to a dedicated branch and create a pull request from the dedicated branch to the destination branch.
The action creates a local branch with specified name (dedicatedBranch), adds and commits changes to this branch, and force pushes to the remote dedicated branch.

## How to use

The action can ble implemented in github-actions as this:

```yaml
on:
  push: 
    branches: 
      - feature-branch
jobs:
  Update-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2 #Checkout feature-branch
      - name: Do some changes
        shell: pwsh
        run: |
          # DO SOME CHANGES
      - name: Create Pull Request
        # See table for ref (Commit or tag)
        uses: equinor/OmniaAutomation/actions/create-pull-request/v2@6ef0a424c9b39f87ecd5ff0d4168a66c7cd2ed6c
        with:
          Token: ${{ secrets.GITHUB_TOKEN }} # Required
          title: "Automatic update"
          body: |
            **Automatic update from 'Update-pipeline'**
            Checklist for approving pull request:
              - [ ] Look for syntax error
              - [ ] No damaging code
              - [ ] This
              - [ ] That
            Only approve if:
              - This
              - That
          dedicatedBranch: "Temporary-Branch" # A branch that will be overwritten each run
          destinationBranch: "main"           # The pull request target branch
          force: false                        # Will overwrite dedicated branch even if last commit was not performed by the action.
```

| Version |                Commit ref                | Notes |
| :-----: | :--------------------------------------: | :---: |
|   v1    | 10a0f43ea188df64e3a7f050f68f3258726e44ae | Initial version |
|   v2    | 6ef0a424c9b39f87ecd5ff0d4168a66c7cd2ed6c | Support for destination branch                                     |
|   v3    | b2a968fc7e8d4caf84a771d32a01181e7884423c | Force parameter allows for other commit authors on dedicated branch |

## Limitations

It is per v2 only allowed to create pull request to one destination branch from a dedicated branch.
If two or more pull requests are desired, please use two seperate dedicated branches.

## Additional information

If destination branch is "Current", the pull request will use the checked out branch as destination.
