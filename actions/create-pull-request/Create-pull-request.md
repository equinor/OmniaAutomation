# Create Pull Request

## Description

This action will move changes form the checked out branch to a dedicated branch and create a pull request from the dedicated branch to the destination branch.
The action creates a local branch with specified name (dedicatedBranch), adds and commits changes to this branch, and force pushes to the remote dedicated branch.

## How to use

The action can ble implemented in github-actions as this:

```yaml
jobs:
  Update-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Do some changes
        shell: pwsh
        run: |
          # DO SOME CHANGES
      - name: Create Pull Request
        # See table for ref (Commit or tag)
        uses: equinor/OmniaAutomation/actions/create-pull-request/v1@10a0f43ea188df64e3a7f050f68f3258726e44ae
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
          dedicatedBranch: "Policy-Documentation-Update"
```

| Version |                Commit ref                |
| :-----: | :--------------------------------------: |
|   v1    | 10a0f43ea188df64e3a7f050f68f3258726e44ae |
|   v2    | 6ef0a424c9b39f87ecd5ff0d4168a66c7cd2ed6c |

## Limitations

It is not allowed to use an already created branch as dedicated branch.
This is to prevent unwanted overwriting of branches.
