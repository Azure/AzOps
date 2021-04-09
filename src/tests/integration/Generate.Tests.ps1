$moduleRoot = (Resolve-Path "$global:testroot\..").Path

Describe "" {
    BeforeAll {}

    Context "" {

        Initialize-AzOpsRepository

    }
}