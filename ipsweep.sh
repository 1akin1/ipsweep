#!/bin/bash

echo "--------------------------------------------------------------"
echo "| IIIIII  PPPPPP   SSSSSSS w    W    W EEEEEEE EEEEEE PPPPPP |"
echo "|   II    P    P   S       w    W    W E       E      P    P |"
echo "|   II    P    P   S       W    W    W E       E      P    P |"
echo "|   II    PPPPP    SSSSSS  w    W    W EEEEEEE EEEEEE PPPPP  |"
echo "|   II    P             S  W    W    W E       E      P      |"
echo "|   II    P             S  W    W    W E       E      P      |"
echo "| IIIIII  P       SSSSSSS  WWWWWWWWWWW EEEEEEE EEEEEE P      |"
echo "--------------------------------------------------------------"

choices(){
  echo "Please select an option(1/2/3)"
  echo "1)Automate the progress"
  echo "2)Enter an IP manually"
  echo "3)Quit"
}

result=1

choice1(){
clear
address="$(ifconfig | grep broadcast | awk '{print $2}')"
new=${address%.*}
echo "------------------------------------------------------"
echo "Your Ip address is: $address"
echo "------------------------------------------------------"
}

choice2(){
clear
read -p "Enter your IP address:" address
new=${address%.*}
echo "------------------------------------------------------"
echo "Your Ip address is: $address"
echo "------------------------------------------------------"
}

choice3(){
exit 130
clear
}

while [ "$result" -eq 1 ]; do
choices
read -p "Enter:" num
case $num in
  1) choice1 ;;
  2) choice2 ;;
  3) choice3 ;;
  *) echo "Invalid choice, please enter a number given below" ;;
esac
  if [ "$num" -eq 1 ] || [ "$num" -eq 2 ];
  then
  break
  fi

echo
done

if [ "$new" == "" ]
then
echo "ERROR COULD NOT FIND AN IP ADDRESS"

else
read -p  "Do you want to start the progress?(Y/N): " confirm
if [[ "$confirm" == [yY] || "$confirm" == [yY][eE][sS] ]];
then
echo -ne '########################--------------------------------------------------------------------------- %25\r'
sleep 0.5
echo -ne '#################################################-------------------------------------------------- %50\r'
sleep 0.5
echo -ne '##########################################################################------------------------- %75\r'
sleep 0.5
echo -ne '################################################################################################### %100\n'
sleep 0.5
echo -ne 'DONE!\n'
echo "---------------------------------------------------------------------------------------------------"
echo "Found:"
out="ip.txt"
for ip in `seq 1 254`; do
  ping $new.$ip -c 1 | grep "64 bytes" | cut -d " " -f 4 | tr -d ":" >> "$out" &  
done 
cat ip.txt
echo "---------------------------------------------------------------------------------------------------"
read -p  "Do you want to start nmap?(Y/N): " confirm
if [[ "$confirm" == [yY] || "$confirm" == [yY][eE][sS] ]];
then
for ip1 in $(cat ip.txt);do
nmap $ip1;
done
rm ip.txt
else
rm ip.txt
fi
fi
fi
