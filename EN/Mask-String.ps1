function Mask-String {
    param (
        [Parameter(Mandatory=$true)]
        [string]$String
    )

    if ($String.Length -le 4) {
        # If the password is very short, do not mask
        return '*' * $String.Length
    }

    $firstPart = $String.Substring(0, 2)
    $lastPart = $String.Substring($String.Length - 2, 2)
    $maskedPart = '*' * ($String.Length - 4)

    return "$firstPart$maskedPart$lastPart"
}

# Example usage
# Mask a string longer than 4 characters
$maskedString = Mask-String -String "SuperSecretPassword"
Write-Host "Masked: $maskedString"

# Mask a string of 4 characters or less
$shortString = Mask-String -String "1234"
Write-Host "Masked: $shortString"