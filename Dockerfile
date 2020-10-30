FROM mcr.microsoft.com/powershell:latest

LABEL repository="https://github.com/Azure/AzOps"
LABEL maintainer="Microsoft"

ARG github=0.11.0
ARG azure_accounts=1.9.2
ARG azure_resources=2.4.0

RUN [ "/bin/bash", "-c", "apt-get update &> /dev/null && apt-get install -y git wget &> /dev/null" ]
RUN [ "/bin/bash", "-c", "wget https://github.com/cli/cli/releases/download/v${github}/gh_${github}_linux_amd64.deb -O /tmp/gh_${github}_linux_amd64.deb  &> /dev/null" ]
RUN [ "/bin/bash", "-c", "curl -sL https://aka.ms/InstallAzureCLIDeb | bash &> /dev/null"]
RUN [ "/bin/bash", "-c", "az extension add --name azure-devops --system &> /dev/null"]
RUN [ "/bin/bash", "-c", "dpkg -i /tmp/gh_${github}_linux_amd64.deb &> /dev/null" ]
RUN [ "/usr/bin/pwsh", "-Command", "$ProgressPreference = 'SilentlyContinue'; Install-Module -Name Az.Accounts -RequiredVersion ${azure_accounts} -Scope AllUsers -Force" ]
RUN [ "/usr/bin/pwsh", "-Command", "$ProgressPreference = 'SilentlyContinue'; Install-Module -Name Az.Resources -RequiredVersion ${azure_resources} -Scope AllUsers -Force" ]

COPY . /var/lib/app

ENV AzOpsMainTemplate='/var/lib/app/template/template.json'
ENV AzOpsStateConfig='/var/lib/app/src/AzOpsStateConfig.json'

ENTRYPOINT ["pwsh", "/var/lib/app/entrypoint.ps1"]
