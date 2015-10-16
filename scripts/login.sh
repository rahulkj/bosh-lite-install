#!/bin/bash

#set user [lindex $argv 0]
user=$1

#set password [lindex $argv 1]
password=$2

cmd1=$(expect << EOF
	set timeout 1
	
	spawn su $user

	expect "Password:"

	send "$password\r";

	expect {
		{ 
			"su: Sorry" {
				send_user "Wrong Password"
				exit 1
			}
			"bash-3.2$" {
				send_user "login success"
				send "exit"
			}
		}
EOF)

echo "$cmd1"
