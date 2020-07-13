FROM mcr.microsoft.com/powershell:latest

LABEL repository="https://github.com/Azure/AzOps"
LABEL maintainer="Microsoft"

ARG github=0.10.0
ARG azure_accounts=1.8.1
ARG azure_resources=2.0.1

RUN [ "/bin/bash", "-c", "apt-get update &> /dev/null && apt-get install -y git wget &> /dev/null" ]
RUN [ "/bin/bash", "-c", "wget https://github.com/cli/cli/releases/download/v${github}/gh_${github}_linux_amd64.deb -O /tmp/gh_${github}_linux_amd64.deb  &> /dev/null" ]
RUN [ "/bin/bash", "-c", "dpkg -i /tmp/gh_${github}_linux_amd64.deb &> /dev/null" ]
RUN [ "/usr/bin/pwsh", "-Command", "$ProgressPreference = 'SilentlyContinue'; Install-Module -Name Az.Accounts -RequiredVersion ${azure_accounts} -Scope AllUsers -Force" ]
RUN [ "/usr/bin/pwsh", "-Command", "$ProgressPreference = 'SilentlyContinue'; Install-Module -Name Az.Resources -RequiredVersion ${azure_resources} -Scope AllUsers -Force" ]

COPY . /action

ENV AzOpsMainTemplate='/action/template/template.json'
ENV AzOpsStateConfig='/action/src/AzOpsStateConfig.json'

ENTRYPOINT ["pwsh", "/action/entrypoint.ps1"]
