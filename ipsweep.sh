#!/bin/bash
echo "--------------------------------------------------------------"
echo "| IIIIII  PPPPPP   SSSSSSS w    W    W EEEEEEE EEEEEE PPPPPP |"
echo "|   II    P    P   S       w    W    W E       E      P    P |"
echo "|   II    P    P   S       W    W    W E       E      P    P |"
echo "|   II    PPPPP    SSSSSS  w    W    W EEEEEEE EEEEEE PPPPP  |"
echo "|   II    P             S  W    W    W E       E      P      |"
echo "|   II    P             S  W    W    W E       E      P      |"
echo "| IIIIII  P       SSSSSSS  WWWWWWWWWWW EEEEEEE EEEEEE P      |"
echo "|                                                 -by 1akin1 |"
echo "--------------------------------------------------------------"

# Function to display choices
choices() {
  echo "Please select an option (1/2/3):"
  echo "1) Automate the progress"
  echo "2) Enter an IP manually"
  echo "3) Quit"
}

# Variable to store the result
result=1

# Function for choice 1
choice1() {
  clear
  address=$(hostname -I | awk '{print $1}')
  new=$(echo "$address" | grep -oE '([0-9]+\.){3}')  # Extract network prefix
  echo "------------------------------------------------------"
  echo "Your IP address is: $address"
  echo "------------------------------------------------------"
}

# Function for choice 2
choice2() {
  clear
  read -p "Enter your IP address: " address
  new=$(echo "$address" | grep -oE '([0-9]+\.){3}')
  echo "------------------------------------------------------"
  echo "Your IP address is: $address"
  echo "------------------------------------------------------"
}

# Function for choice 3
choice3() {
  exit 0
}

# Loop to display choices and get user input
while [ "$result" -eq 1 ]; do
  choices
  read -p "Enter: " num
  case $num in
    1) choice1 ;;
    2) choice2 ;;
    3) choice3 ;;
    *) echo "Invalid choice, please enter a number from the list" ;;
  esac
  if [ "$num" -eq 1 ] || [ "$num" -eq 2 ]; then
    break
  fi
  echo
done

# Check if a valid IP address is found
if [ -z "$new" ]; then
  echo "ERROR: COULD NOT FIND A VALID IP ADDRESS"
  exit 1
else
  # Prompt user to start the progress
  read -p "Do you want to start the progress? (Y/N): " confirm
  if [[ "$confirm" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo -ne 'DONE!\n'
    echo "---------------------------------------------------------------------------------------------------"
    echo "Found:"
    out="ip.txt"
    
    # Ensure file does not exist before scanning
    > "$out"

    # Loop to ping all possible addresses in the subnet
    for ip in $(seq 1 254); do
      (ping -c 1 -W 1 "$new$ip" | grep "64 bytes" | awk '{print $4}' | tr -d ":" >> "$out") &
    done
    wait  # Ensure all background tasks finish

    # Display the active IPs found in the output file
    cat "$out"
    echo "---------------------------------------------------------------------------------------------------"
    # Ask the user if they want to delete the output file
    read -p "Do you want to delete the output file (ip.txt)? (Y/N): " delete_file
    # Check if the user wants to delete the file
    if [[ "$delete_file" =~ ^[Yy]([Ee][Ss])?$ ]]; then
      # Remove the output file
      rm -f "$out"
      echo "Output file ip.txt deleted."
    else
      # If the user does not want to delete the file, inform them it will be kept
      echo "Output file ip.txt kept."
    fi
    fi
    fi
