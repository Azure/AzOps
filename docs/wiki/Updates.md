
1. Add remote upstream

    ```bash
    git remote add  upstream https://github.com/Azure/AzOps-Accelerator.git
    ```

2. Pull upstream changes

    ```bash
    git pull upstream main --allow-unrelated-histories -X theirs
    ```
