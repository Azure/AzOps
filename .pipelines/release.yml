---
name: 'AzOps - Release'

#
# Triggers
#

trigger: none

pool:
  vmImage: "ubuntu-20.04"

jobs:

  - job: release
    displayName: 'Release'
    steps:

      #
      # Checkout
      # Checks-out the repository
      #

    - checkout: self
      fetchDepth: 0

      #
      # Dependencies
      # Retrieve required modules from PSGallery
      #

    - task: PowerShell@2
      displayName: 'Dependencies'
      inputs:
        targetType: 'inline'
        script: |
          ./scripts/Dependency.ps1

      #
      # Package
      # Prepare the modules for upload
      #

    - task: PowerShell@2
      displayName: 'Package'
      inputs:
        targetType: 'inline'
        script: |
          ./scripts/Release.ps1 -LocalRepo

      #
      # Authenticate
      #

    - task: NuGetAuthenticate@0
      displayName: 'Authenticate'

      #
      # Push
      # Upload the packages to Azure Artifacts
      #

    - task: NuGetCommand@2
      displayName: 'Push'
      inputs:
        command: push
        publishVstsFeed: '$(System.TeamProject)/$(FEED_NAME)'
        allowPackageConflicts: false
        packagesToPush: 'publish/AzOps.*.nupkg'
