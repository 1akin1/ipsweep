📌 Overview

This is a Bash script that automates the process of finding active IP addresses in a local network. The script provides an option to automatically detect the local subnet or manually enter an IP address.

🎯 Features

Automated Detection: Retrieves the local IP address and subnet automatically.

Manual Entry: Users can manually input an IP address if automatic detection fails.

Network Scanning: Pings all possible addresses within the subnet to find active hosts.

Simple UI: Displays available options and results in an easy-to-read format.

Asynchronous Execution: Runs the scanning process in parallel for efficiency.

🛠 Requirements

This script is designed for Linux/macOS systems with bash and ping installed.

🚀 How to Run the Script

Download or clone this repository.

Open a terminal and navigate to the directory containing the script.

Run the script using the command:

chmod +x ip_scanner.sh
./ip_scanner.sh

📝 Usage Instructions

Choose an option from the menu:

1: Automatically detect and scan the local network.

2: Manually enter an IP address to scan.

3: Exit the script.

If an IP address is found, confirm whether you want to start the scanning process.

The script pings all possible addresses in the subnet and displays the active IPs.

⚠️ Error Handling

If no IP address is detected, an error message will be displayed.

The script ensures only valid options can be selected.

👨‍💻 Author

1akin1

