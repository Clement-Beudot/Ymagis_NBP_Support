#!/bin/bash
export NEWT_COLORS='
window=black,black
root=black,black
title=white,black
border=white,black
textbox=white,black
button=black,green
listbox=white,black
sellistbox=yellow,green
actlistbox=green,black
actsellistbox=black,green
entry=white,black
roottext=white,black
'

##################################################################################
#                                                                                #
#                               Support_nbp.sh                                   #
#                                                                                #
#                               Version B 2.6.1                                  #
#                                                                                #
#                               Author : c.beudot                                #
#                               12-05-2019                                       #
#                                                                                #
##################################################################################
#
# 12-08-2019 (B_2.6.1 Test version) :
# - add *playlists* to the -t option to show and update SPL push status 
#
#
# 11-08-2019 (B_2.6.0) :
#  - Possibility to enable / disable push config when you change it.
#  - Possibility to run this script logged in as ROOT user disabled
#  - Add -s (--show) option to print the push config
#  - Add -f (--ftp) option to connect directly to the library filled for DCPs in push config
#  - -u (--update_track) option changed to -t (or --track_update)
#  - -i (--ip) option changed to -u (or --upload)
#
# 06-08-2019 (Patch B_2.5.2) :
#  - Replace AWK command by Grep command to get the DCP UUIDs (didn't work with some ASSETMAPs written with the feet)
#
# 16-07-2019 / 27-07-2019 (B_2.5) :
#  - List and Push playlists work also with C+regie (*%£# reversed dates)
#  - Add -u (--update_track) to get and update DCP_UUIDs push status if needed
#
# 14-06-2019 (B_2.4) :
#  - Add -m (--mtu) option to get the best mtu value for tun1 on receiver
#
# 22-05-2019 (B_2.3) :
#  - Shared version 
#
# 22-05-2019 (B_2.3) :
#  - Show limit bandwitdh config
# 
# 21-05-2019 (B_2.2) :
#  - Push enabled for current and next playlists
#  - Add --check option to print check logs in shell
# 
# 
# 19-05-2019 (B_2.1) : 
#  - FTP session for DCP and PLAYLIST configuration
#  - Add check_nbp.sh in Check NBP configuration
#  - Add test if distant PATHs exists for push config(S)



push_config="/etc/nbp/automation/ftp-push.yml"
login_upload=""
end_dns="orc0001.ymagis.net"
title="Support NBP help tool Beta 2.6.1"

ftp_enable=''

login_ftp_dcp=''
password_ftp_dcp=''
ip_library_dcp=''
path_dcp=''
status_dcp_pushconfig="test"
status_dcp_path=""

login_ftp_playlists=''
password_ftp_playlists=''
ip_library_playlists=''
path_playlists=''
status_playlists_pushconfig=""
status_playlist_path=""

no_color="\033[0m"
red="\033[0;31m"
green="\033[0;32m"
Yellow="\033[0;33m"
Cyan="\033[0;36m"

mtu_high_value="1500"

function get_date(){

	log_date=`date +%Y-%m-%d_%H.%M`
	actual_day_nb=`date +%w`

	if [ "$actual_day_nb" -lt "3" ]; then 
	{
		let "step_next_wednesday=3 - $actual_day_nb"	
	}
	else
	{
		let "step_next_wednesday=$actual_day_nb - 3"
		let "step_next_wednesday=7 - $step_next_wednesday"
	}
	fi
	let "step_previous_wednesday=step_next_wednesday - 7"
	next_wednesday="$(date -d "$date +$step_next_wednesday days" +"%d%m%Y")"
	reversed_next_wednesday="$(date -d "$date +$step_next_wednesday days" +"%Y%m%d")"
	previous_wednesday="$(date -d "$date -$step_previous_wednesday days" +"%d%m%Y")"
	reversed_previous_wednesday="$(date -d "$date -$step_previous_wednesday days" +"%Y%m%d")"
}

function get_push_config(){

	if [ ! -f $push_config ]; then
		{
		echo -e "\n$red There is no pushconfig : $push_config no such file $no_color"
		echo -e "$red Are you on an Orchestra System ?$no_color\n"
		exit
		}
	else
		{
		ftp_enable=`grep FTP_ENABLE $push_config | cut -d \' -f 2`
		login_ftp_playlists=`grep FTP_USERNAME_PLAYLIST $push_config | cut -d \' -f 2`
		password_ftp_playlists=`grep FTP_PASSWORD_PLAYLIST $push_config | cut -d \' -f 2`
		ip_library_playlists=`grep FTP_HOST_PLAYLIST $push_config | cut -d \' -f 2`
		path_playlists=`grep FTP_ROOT_PATH_PLAYLIST $push_config | cut -d \' -f 2`
		login_ftp_dcp=`grep FTP_USERNAME $push_config | grep -v PLAYLIST |  cut -d \' -f 2`
		password_ftp_dcp=`grep FTP_PASSWORD $push_config | grep -v PLAYLIST | cut -d \' -f 2`
		ip_library_dcp=`grep FTP_HOST $push_config | grep -v PLAYLIST | cut -d \' -f 2`
		path_dcp=`grep FTP_ROOT_PATH $push_config | grep -v PLAYLIST | cut -d \' -f 2`
		straight_path_dcp=`echo $path_dcp | sed 's/^\///'`
		straight_path_playlists=`echo $path_playlists | sed 's/^\///'`
		}	
	fi
}

function change_push_config(){

	get_push_config
	get_date
	if (whiptail --title "ftp-push.yml" --yesno "Do you want to Enable Push Config ?\nIf you answer Disable, this receiver will be in pull only" --yes-button "Enable" --no-button "Disable" --backtitle "$title" 10 60); then
	{
		if (whiptail --title "ftp-push.yml" --yesno "Do you want to change Push Config for DCP ?" --backtitle "$title" 10 60); then
		{
			ip_library_dcp=$(whiptail --inputbox "Library IP adress for DCP :" 10 78 $ip_library_dcp  --title "ftp-push.yml - DCP section" --nocancel --backtitle "$title" 3>&1 1>&2 2>&3)
			login_ftp_dcp=$(whiptail --inputbox "Library ftp login for DCP :" 10 78 $login_ftp_dcp  --title "ftp-push.yml - DCP section" --nocancel --backtitle "$title" 3>&1 1>&2 2>&3)
			password_ftp_dcp=$(whiptail --inputbox "Library ftp password for DCP :" 10 78 $password_ftp_dcp  --title "ftp-push.yml - DCP section" --nocancel --backtitle "$title" 3>&1 1>&2 2>&3)
			path_dcp=$(whiptail --inputbox "Library path for DCP :" 10 78 $path_dcp  --title "ftp-push.yml - DCP section" --nocancel --backtitle "$title" 3>&1 1>&2 2>&3)
		}
		fi
		if (whiptail --title "ftp-push.yml" --yesno "Do you want to change Push Config for PLAYLISTS ?" 10 60); then
		{
			ip_library_playlists=$(whiptail --inputbox "Library IP adress for PLAYLISTS :" 10 78 $ip_library_playlists  --title "ftp-push.yml - PLAYLISTS section" --nocancel --backtitle "$title" 3>&1 1>&2 2>&3)
			login_ftp_playlists=$(whiptail --inputbox "Library ftp login for PLAYLISTS :" 10 78 $login_ftp_playlists  --title "ftp-push.yml - PLAYLISTS section" --nocancel --backtitle "$title" 3>&1 1>&2 2>&3)
			password_ftp_playlists=$(whiptail --inputbox "Library ftp password for PLAYLISTS :" 10 78 $password_ftp_playlists  --title "ftp-push.yml - PLAYLISTS section" --nocancel --backtitle "$title" 3>&1 1>&2 2>&3)
			path_playlists=$(whiptail --inputbox "Library path for PLAYLISTS :" 10 78 $path_playlists  --title "ftp-push.yml - PLAYLISTS section" --nocancel --backtitle "$title" 3>&1 1>&2 2>&3)	
		}
		fi
		ftp_enable='yes'
	}
	else
	{
		ftp_enable='no'
	}
	fi
	if (whiptail --title "ftp-push.yml" --yesno "Warning !\nDo you want to erase ftp-push.yml ?\nA backup will be generated." --backtitle "$title" 15 60); then
	{
		sudo cp $push_config $push_config.save.$log_date
		echo -e "FTP_ENABLE: '$ftp_enable' \nFTP_PORT: '21'" | sudo tee $push_config > /dev/null 2>&1
		echo -e "FTP_HOST: '$ip_library_dcp'\nFTP_USERNAME:  '$login_ftp_dcp' \nFTP_PASSWORD: '$password_ftp_dcp' \nFTP_ROOT_PATH: '$path_dcp'" | sudo tee -a $push_config > /dev/null 2>&1
		echo -e "FTP_PORT_PLAYLIST: '21'" | sudo tee -a $push_config > /dev/null 2>&1
		echo -e "FTP_HOST_PLAYLIST: '$ip_library_playlists' \nFTP_USERNAME_PLAYLIST: '$login_ftp_playlists' \nFTP_PASSWORD_PLAYLIST: '$password_ftp_playlists' \nFTP_ROOT_PATH_PLAYLIST: '$path_playlists'" | sudo tee -a $push_config > /dev/null 2>&1
		whiptail --title "NEW ftp-push.yml" --textbox $push_config --backtitle "$title" 20 60
		if (whiptail --title "Restart NBP ?" --yesno "\nDo you want to restart NBP now ?" --backtitle "$title" 15 60); then
		{
			sudo manage_nbp.sh restart
		}
		fi
	}
	fi	
}

function list_xml_content(){

	get_date
	nbp_repo=`sudo grep HOST_BASE_STORAGE_FOLDER /var/lib/nbp/.env | cut -d '=' -f2`
	cd $nbp_repo && cd storage/export
	if [ -d "assets-folder" ] ; then
	{
		WEEK=$(
		whiptail --title "$0" --menu "Make your choice" --backtitle "$title" 16 60 9 \
				"1)" "Show current week playlists."   \
				"2)" "Show next week playlists."  \
				"3)" "Push current week playlists."  \
				"4)" "Push next week playlists."  \
				 3>&2 2>&1 1>&3	
			)

		
		if [ "$?" = "0" ]; then
		{
			if [ "$WEEK" = "1)" ];then
			{
				find assets-folder | grep -i .xml | sed 's/[^/]*\//| /g;s/| *\([^| ]\)/+- \1/' | grep -i $previous_wednesday > $HOME/xml_list.tmp
				find assets-folder | grep -i .xml | sed 's/[^/]*\//| /g;s/| *\([^| ]\)/+- \1/' | grep -i $reversed_previous_wednesday >> $HOME/xml_list.tmp
				whiptail --title "List XML" --textbox $HOME/xml_list.tmp --scrolltext --backtitle  "$title" 15 70
			}
			fi
			if [ "$WEEK" = "2)" ];then
			{
				find assets-folder | grep -i .xml | sed 's/[^/]*\//| /g;s/| *\([^| ]\)/+- \1/' | grep -i $next_wednesday > $HOME/xml_list.tmp
				find assets-folder | grep -i .xml | sed 's/[^/]*\//| /g;s/| *\([^| ]\)/+- \1/' | grep -i $reversed_next_wednesday >> $HOME/xml_list.tmp
				whiptail --title "List XML" --textbox $HOME/xml_list.tmp --scrolltext --backtitle  "$title" 15 70
			}
			fi
			if [ "$WEEK" = "3)" ];then
			{
				sorted_date=$previous_wednesday
				inverted_date=$reversed_previous_wednesday
				push_xml_content				
			}
			fi
			if [ "$WEEK" = "4)" ];then
			{
				sorted_date=$next_wednesday
				inverted_date=$reversed_next_wednesday
				push_xml_content				
			}
			fi
			
		}
		fi
	}
	else
	{
		whiptail --title "Information" --msgbox "There is no .xml files or assets-folder directory here" --backtitle "$title" 10 60
	}
	fi
	cd $HOME
}

function push_xml_content(){

	get_push_config
	echo -e "\n\n___ START Push log for $sorted_date at $log_date ___\n" >> $HOME/log.push.support_nbp
	lftp $login_ftp_playlists:$password_ftp_playlists@$ip_library_playlists -e  "set net:timeout 5;set net:max-retries 1; cd $straight_path_playlists; quit" > /dev/null 2>&1
	if [ "$?" = "0" ]; then
	{
		echo -e "Distant Path => $straight_path_playlists : OK\n" >> $HOME/log.push.support_nbp
		cd assets-folder > /dev/null 2>&1
		mkdir $HOME/tmp_playlists > /dev/null 2>&1
		cp */*$sorted_date*.xml $HOME/tmp_playlists > /dev/null 2>&1
		cp */*$inverted_date*.xml $HOME/tmp_playlists > /dev/null 2>&1
		cd $HOME/tmp_playlists > /dev/null 2>&1
		echo -e "List of XML about to be pushed : \n" >> $HOME/log.push.support_nbp
		ls >> $HOME/log.push.support_nbp
		echo -e "\nPushing : \n" >> $HOME/log.push.support_nbp
		lftp $login_ftp_playlists:$password_ftp_playlists@$ip_library_playlists -e "set net:timeout 5;set net:max-retries 1; cd $straight_path_playlists; mirror -R --only-missing -v; quit" >> $HOME/log.push.support_nbp
		rm -rf $HOME/tmp_playlists > /dev/null 2>&1
	}
	else 
	{
		echo -e "An error as occured, checking...\n" >> $HOME/log.push.support_nbp
		echo -e "Test ping :\n" >> $HOME/log.push.support_nbp
		ping -c 3 $ip_library_playlists >> $HOME/log.push.support_nbp
		echo -e "\n\n result ping : $?" >> $HOME/log.push.support_nbp
		if [ "$?" = "0" ]; then
		{
			echo -e "\nTesting FTP connection with the remote server\n" >> $HOME/log.push.support_nbp
			lftp $login_ftp_playlists:$password_ftp_playlists@$ip_library_playlists -e  "set net:timeout 5;set net:max-retries 1; ls -lrt; quit" > /dev/null 2>&1
			if [ "$?" = "0" ]; then
			{
				echo -e "\nFTP connection with the remote server : OK" >> $HOME/log.push.support_nbp
				echo -e "\nThere is a problem with Path $straight_path_playlists , please check configuration" >> $HOME/log.push.support_nbp
			}
			else
			{
				echo -e "\n There is a problem with FTP playlist credentials,  please check configuration" >> $HOME/log.push.support_nbp
			}
			fi
		}
		else
		{
			echo -e "\n There is no connection with the remote server" >> $HOME/log.push.support_nbp
		}
		fi
	}
	fi
	echo -e "\n___ END Push log for $sorted_date at $log_date ___\n" >> $HOME/log.push.support_nbp
	whiptail --title "Push logs" --textbox $HOME/log.push.support_nbp --scrolltext --backtitle  "$title" 20 70
	
}

function upload_script(){
	clear
	echo -e "___UPLOADIND SCRIPT___\nTrying : $Cyan $login_upload $no_color , please wait. \n"
	scp $0 $login_upload:
	if [ "$?" = "0" ]; then
		{
		echo -e "\nUpload : $green OK $no_color Now, use $green./script_name$no_color to continue \n"
		}
	else
		{
		echo -e "\nUpload : $red Error $no_color , please check your credentials \n"
		exit 2
		}
	fi
	ssh $login_upload
}

function check_configuration(){

    {
    get_push_config
    sleep 1
    echo XXX; echo 10; echo "Checking connection for DCP Pushconfig"; echo XXX
    if [ "$login_ftp_dcp" = '' ] || [ "$password_ftp_dcp" = '' ] || [ "$ip_library_dcp" = '' ]; then
    	{
    		status_dcp_pushconfig="Not Configured"
    	}
    else
    	{
		lftp $login_ftp_dcp:$password_ftp_dcp@$ip_library_dcp -e  "set net:timeout 5;set net:max-retries 1; ls -lrt; quit" > /dev/null 2>&1
		if [ "$?" = "0" ]; then
		{
			status_dcp_pushconfig="OK"
		}
		else
		{
			echo XXX; echo 20; echo "Ping $ip_library_dcp"; echo XXX
			ping -c 3 $ip_library_dcp &> /dev/null && status_ping_dcp="NOK\nRemote Host : Reachable" || status_ping_dcp="NOK\nRemote Host : Unreachable"
			status_dcp_pushconfig="$status_ping_dcp"
		}
		fi
    	}
    fi
    sleep 1
    echo XXX; echo 30; echo "Checking distant Path for DCP pushconfig"; echo XXX
    if [ "$status_dcp_pushconfig" = "OK" ];then 
    	{
    	lftp $login_ftp_dcp:$password_ftp_dcp@$ip_library_dcp -e  "set net:timeout 5;set net:max-retries 1; cd $straight_path_dcp; quit" > /dev/null 2>&1
    	if [ "$?" = "0" ]; then
		{
			status_dcp_path="OK"
		}
		else
		{
			status_dcp_path="Wrong path"
		}
		fi
    	}
    else
    	{
    		status_dcp_path="Not tested"
    	}
    fi
    sleep 1  
    echo XXX; echo 40; echo "Checking connection for PLAYLIST Pushconfig"; echo XXX    
    if [ "$login_ftp_playlists" = '' ] || [ "$password_ftp_playlists" = '' ] || [ "$ip_library_playlists" = '' ]; then
    	{
    		status_playlists_pushconfig="Not Configured"
    	}
    else
    	{
		lftp $login_ftp_playlists:$password_ftp_playlists@$ip_library_playlists -e  "set net:timeout 5;set net:max-retries 1; ls -lrt; quit" > /dev/null 2>&1
		if [ "$?" = "0" ]; then
		{
			status_playlists_pushconfig="OK"
		}
		else
		{
			echo XXX; echo 50; echo "Ping $ip_library_playlists"; echo XXX
			ping -c 3 $ip_library_playlists &> /dev/null && status_ping_playlists="NOK\nRemote Host : Reachable" || status_ping_playlists="NOK\nRemote Host : Unreachable"
			status_playlists_pushconfig="$status_ping_playlists"
		}
		fi
    	}
    fi
    sleep 1
    echo XXX; echo 60; echo "Checking distant Path for PLAYLIST pushconfig"; echo XXX
    if [ "$status_playlists_pushconfig" = "OK" ];then 
    	{
    	lftp $login_ftp_playlists:$password_ftp_playlists@$ip_library_playlists -e  "set net:timeout 5;set net:max-retries 1; cd $straight_path_playlists; quit" > /dev/null 2>&1
    	if [ "$?" = "0" ]; then
		{
			status_playlist_path="OK"
		}
		else
		{
			status_playlist_path="Wrong path"
		}
		fi
    	}
    else
    	{
    		status_playlist_path="Not tested"
    	}
    fi
    sleep 1
    echo XXX; echo 80; echo "check_nbp.sh all"; echo XXX
    sudo check_nbp.sh all > $HOME/tmp.check_nbp.log
    echo 100
    echo -e "PUSH CONFIGURATION STATUS : " > $HOME/log.check.support_nbp
    echo -e "\nDCP Push config : $status_dcp_pushconfig \nDistant Path for DCP : $status_dcp_path" >> $HOME/log.check.support_nbp
    echo -e "\nPLAYLISTS Push config : $status_playlists_pushconfig \nDistant Path for PLAYLISTS : $status_playlist_path" >> $HOME/log.check.support_nbp
    echo -e "\nftp-push.yml : \n" >> $HOME/log.check.support_nbp
    cat $push_config >> $HOME/log.check.support_nbp
    echo -e "\nCHECK_NBP.SH ALL : \n" >> $HOME/log.check.support_nbp
    cat -A tmp.check_nbp.log | sed 's/\^\[\[0;3[1-2]m//' | sed 's/\^\[\[0m//' | sed 's/\$//' >> $HOME/log.check.support_nbp
    echo -e "\nPORTS STATUS : \n" >> $HOME/log.check.support_nbp
    sudo grep '' /var/lib/zabbix_trap/config.containers.nbp.* >> $HOME/log.check.support_nbp
    rm $HOME/tmp.check_nbp.log
	} | whiptail --gauge "Checking NBP status and push configuration"  --backtitle "$title" 6 60 0
	whiptail --title "NBP Status" --textbox $HOME/log.check.support_nbp --scrolltext --backtitle "$title" 20 60
}

function check_capping(){

	capping_file="/etc/nbp/transmission-info/settings.json"
	speed_limit_down_enabled=`grep speed-limit-down-enabled $capping_file | cut -d \: -f2 | sed 's/ //' | sed 's/,//'`
	speed_limit_down=`grep speed-limit-down $capping_file | grep -v enabled | cut -d \: -f2 | sed 's/ //' | sed 's/,//'`
	speed_limit_up_enabled=`grep speed-limit-up-enabled $capping_file | cut -d \: -f2 | sed 's/ //' | sed 's/,//'`
	speed_limit_up=`grep speed-limit-up $capping_file | grep -v enabled | cut -d \: -f2 | sed 's/ //' | sed 's/,//'`
	alt_speed_enabled=`grep alt-speed-enabled $capping_file | cut -d \: -f2 | sed 's/ //' | sed 's/,//'`
	alt_speed_time_enabled=`grep alt-speed-time-enabled $capping_file | cut -d \: -f2 | sed 's/ //' | sed 's/,//'`
	alt_speed_time_day=`grep alt-speed-time-day $capping_file | cut -d \: -f2 | sed 's/ //' | sed 's/,//'`
	Dec2Bin=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})
	alt_speed_time_day=${Dec2Bin[$alt_speed_time_day]}
	week_day=( off MON TUE WED THU FRI SAT SUN)
	alt_speed_down=`grep alt-speed-down $capping_file | cut -d \: -f2 | sed 's/ //' | sed 's/,//'`
	alt_speed_up=`grep alt-speed-up $capping_file | cut -d \: -f2 | sed 's/ //' | sed 's/,//'`
	alt_speed_time_begin=`grep alt-speed-time-begin $capping_file | cut -d \: -f2 | sed 's/ //' | sed 's/,//'`
	alt_speed_time_end=`grep alt-speed-time-end $capping_file | cut -d \: -f2 | sed 's/ //' | sed 's/,//'`
	let "begin_minutes=$alt_speed_time_begin%60"
	let "begin_hours=($alt_speed_time_begin-$begin_minutes)/60"
	alt_speed_time_begin="$begin_hours H $begin_minutes"
	let "end_minutes=$alt_speed_time_end%60"
	let "end_hours=($alt_speed_time_end-$end_minutes)/60"
	alt_speed_time_end="$end_hours H $end_minutes"

	echo -e "\nGLOBAL LIMITS :\n" >> $HOME/log.capping.support_nbp
	echo -e "Download limits : $speed_limit_down_enabled : $speed_limit_down" >> $HOME/log.capping.support_nbp
	echo -e "Upload limits : $speed_limit_up_enabled : $speed_limit_up" >> $HOME/log.capping.support_nbp
	echo -e "\nALTERNATIVES LIMITS :\n" >> $HOME/log.capping.support_nbp
	echo -e "Alternative limits : $alt_speed_enabled / $alt_speed_time_enabled \n" >> $HOME/log.capping.support_nbp
	echo -e "From : $alt_speed_time_begin To $alt_speed_time_end \n" >> $HOME/log.capping.support_nbp
	echo -e "Alternative Download limits : $alt_speed_down" >> $HOME/log.capping.support_nbp
	echo -e "Alternative Upload limits : $alt_speed_up \n" >> $HOME/log.capping.support_nbp
	for i in $(seq 1 ${#alt_speed_time_day})
	do
		echo ${week_day[$i]} ${alt_speed_time_day:$i-1:1} >> $HOME/log.capping.support_nbp
	done
	
	whiptail --title "Capping NBP" --textbox $HOME/log.capping.support_nbp --scrolltext --backtitle "$title" 20 60
	rm $HOME/log.capping.support_nbp
}

function check_mtu(){

	ping $ip_test_mtu -c 3 -s $mtu_high_value -M do > /dev/null 2>&1
	if [ "$?" = "0" ]; then
		{
		echo -e "\nMTU $mtu_high_value : $green OK $no_color \n"
		}
	else
		{
		ping $ip_test_mtu -c 5 > /dev/null 2>&1
		if  [ ! "$?" = "0" ]; then
			{
				echo -e "$red Host is unreachable or there is flapping $no_color"
				exit
			}
		fi
		echo -e "MTU $mtu_high_value : $red NOK $no_color"
		mtu_best_value_found=0
		mtu_low_value_found=0
		mtu_high_value_found=0
		while [ "$mtu_low_value_found" = "0" ]; do
			let "mtu_high_value=$mtu_high_value-50"
			ping $ip_test_mtu -c 3 -s $mtu_high_value -M do > /dev/null 2>&1
			if [ "$?" = "0" ]; then
				{
					mtu_low_value_found=1
					echo -e "\nMTU $mtu_high_value : $green OK $no_color \n"
					while [ "$mtu_high_value_found" = "0" ]; do
						let "mtu_high_value=$mtu_high_value+10"
						ping $ip_test_mtu -c 3 -s $mtu_high_value -M do > /dev/null 2>&1
						if [ ! "$?" = "0" ]; then
							{	
							mtu_high_value_found=1
							while [ "$mtu_best_value_found" = "0" ]; do
								let "mtu_high_value=$mtu_high_value-1"
								ping $ip_test_mtu -c 3 -s $mtu_high_value -M do > /dev/null 2>&1
								if [ "$?" = "0" ]; then
									{
									echo -e "\nOptimal MTU value $mtu_high_value : $green OK $no_color \n"
									mtu_best_value_found=1
									}
								else
									{
									echo -e "MTU $mtu_high_value : $red NOK $no_color"
									}
								fi
							done
							}
						else
							{
							echo -e "MTU $mtu_high_value : $green OK $no_color"
							}
						fi
					done
				}
			else
				{
				echo -e "MTU $mtu_high_value : $red NOK $no_color"
				}
			fi
		done
		

		}
	fi
	

}

function force_track_update_dcp(){

	nbp_repo=`sudo grep HOST_BASE_STORAGE_FOLDER /var/lib/nbp/.env | cut -d '=' -f2`
	cd $nbp_repo && cd storage/export
	packages_found=`ls | grep -i $search_area | wc -l`

	
	if [ $packages_found -ne 0 ]; then
		{
			ls | grep -i $search_area > $HOME/tmp_lst_pkg
			while [ "$push_choice" != "q" ]; do
			{
				clear	
				i=1
				while
					read line
				do
					#uuid=`awk '/<AssetMap/,/<\/Id>/{print $1}' $line/ASSETMAP* | grep "<Id>" | cut -d ':' -f3 | cut -d '<' -f1`
					uuid=`grep -Po "<Id>\K(.+?)(?=</Id>)" $line/ASSETMAP* | cut -d ":" -f3 | head -n1`
					track_value=`sudo docker exec client_redis_1 redis-cli get autopush:$uuid:offload_status | cut -d '"' -f 2`
					if [ "$track_value" = "200" ]; then
						{
							color="$green"
							track_value="OK"
						}
					else
						{
							color="$red"
							track_value="FAILED"
						}
					fi
					echo -e "$color 0$i : $line : $uuid _ $track_value" >> $HOME/tmp_lst_pkg-sorted
					((i++))
				done < $HOME/tmp_lst_pkg
				cat $HOME/tmp_lst_pkg-sorted
				echo -e "$no_color"
				
				
				read -p 'Enter a line number to force track update (or enter q to quit):' push_choice

				if [ "$push_choice" != "q" ] && [ "$push_choice" != "" ]; then
					{
						new_value=`grep -i "$push_choice :" $HOME/tmp_lst_pkg-sorted | cut -d ":" -f3 | cut -d "_" -f1 | sed 's/ //g'`
						#echo $new_value
						if [ "$new_value" != "" ]; then
						{
							sudo manage_nbp.sh push $new_value --force
						}
						fi
						
						
					}
				fi
				rm $HOME/tmp_lst_pkg-sorted
			}; done 
			rm $HOME/tmp_lst_pkg

		}
	else
		{
			echo -e "$red \nThere is nothing found with : *$search_area*.$no_color"; 
		}
	fi	
}
function force_track_update_playlists(){

	nbp_repo=`sudo grep HOST_BASE_STORAGE_FOLDER /var/lib/nbp/.env | cut -d '=' -f2`
	cd $nbp_repo && cd storage/export/assets-folder
	packages_found=`ls -lrt */*xml | tail -20 | wc -l`

	
	if [ $packages_found -ne 0 ]; then
		{
			ls -rt */*xml | tail -20 > $HOME/tmp_lst_pkg
			while [ "$push_choice" != "q" ]; do
			{
				clear	
				i=1
				while
					read line
				do
					uuid=`echo "$line" | cut -d "/" -f1`
					track_value=`sudo docker exec client_redis_1 redis-cli get autopush:$uuid:offload_status | cut -d '"' -f 2`
					if [ "$track_value" = "200" ]; then
						{
							color="$green"
							track_value="OK"
						}
					else
						{
							color="$red"
							track_value="FAILED"
						}
					fi
					echo -e "$color 0$i : $line : $uuid _ $track_value" >> $HOME/tmp_lst_pkg-sorted
					((i++))
				done < $HOME/tmp_lst_pkg
				cat $HOME/tmp_lst_pkg-sorted
				echo -e "$no_color"
				
				
				read -p 'Enter a line number to force track update (or enter q to quit):' push_choice

				if [ "$push_choice" != "q" ] && [ "$push_choice" != "" ]; then
					{
						new_value=`grep -i "$push_choice :" $HOME/tmp_lst_pkg-sorted | cut -d ":" -f3 | cut -d "_" -f1 | sed 's/ //g'`
						if [ "$new_value" != "" ]; then
						{
							sudo manage_nbp.sh push $new_value --force
						}
						fi
						
						
					}
				fi
				rm $HOME/tmp_lst_pkg-sorted
			}; done 
			rm $HOME/tmp_lst_pkg

		}
	else
		{
			echo -e "$red \nThere is nothing found in assets-folder.$no_color"; 
		}
	fi	
}


function ftp_session(){

	get_push_config
	FTP_SESSION=$(
	whiptail --title "$0" --menu "Make your choice" --backtitle "$title" 16 60 9 \
			"1)" "Start with DCP credentials"   \
			"2)" "Start with PLAYLIST credentials"  \
			 3>&2 2>&1 1>&3	)

	if [ "$?" = "0" ]; then
	{
		if [ "$FTP_SESSION" = "1)" ];then
		{
			whiptail --title "Information" --msgbox "Starting FTP session to $ip_library_dcp in a screen" --backtitle "$title" 10 60
		  	screen -m lftp $login_ftp_dcp:$password_ftp_dcp@$ip_library_dcp
		}
		else
		{
			whiptail --title "Information" --msgbox "Starting FTP session to $ip_library_playlists in a screen" --backtitle "$title" 10 60
		  	screen -m lftp $login_ftp_playlists:$password_ftp_playlists@$ip_library_playlists
		}
		fi
	}
	fi
}
function ftp_connect(){

	get_push_config
	echo -e "$green \nDCP are pushed in $path_dcp\n $no_color"
	lftp $login_ftp_dcp:$password_ftp_dcp@$ip_library_dcp
}

function clear_and_exit(){

	if [ -f $HOME/xml_list.tmp ] ; then 
	{
		rm $HOME/xml_list.tmp
	}
	fi
	if [ -f $HOME/log.check.support_nbp ] ; then 
	{
		rm $HOME/log.check.support_nbp
	}
	fi
	if [ -f $HOME/log.push.support_nbp ] ; then 
	{
		rm $HOME/log.push.support_nbp $HOME/tmp.check_nbp.log
	}
	fi
	if [ -f $HOME/tmp.check_nbp.log ] ; then 
	{
		rm $HOME/tmp.check_nbp.log 
	}
	fi
}

function main_menu(){
	continue_main_menu="1"
	while [ "$continue_main_menu" = "1" ]
		do
		CHOICE=$(
		whiptail --title "$0" --menu "Make your choice" --nocancel --backtitle "$title" 16 60 9 \
			"1)" "Check NBP and PUSH Status."   \
			"2)" "Show PUSH config."  \
			"3)" "Change PUSH config." \
			"4)" "List and Push XML playlists" \
			"5)" "Start FTP session" \
			"6)" "Show Limit bandwitdth" \
			"9)" "QUIT"  3>&2 2>&1 1>&3	
		)


		
		case $CHOICE in
			"1)")   
				check_configuration
			;;
			"2)")          
				whiptail --title "ftp-push.yml" --textbox $push_config --backtitle "$title" 20 60
			;;
			"3)")       
				change_push_config
		   	;;

			"4)")   
			   	list_xml_content
		        ;;

			"5)") 
		  		ftp_session
		        ;;

			"6)")   
				
				check_capping
		        ;;

			"9)")
				clear_and_exit
				exit
		        ;;
		esac
		
	done


}

################  MAIN OPTIONS ################ 

if [ ! "$USER" = "root" ]; then
{
	if [ "$1" = "" ]; then
		{
		if [ ! -f $push_config ] ; then
		{
			ymg_sitecode=$(whiptail --inputbox "You're not on Orchestra System, enter an Ymagis Site Code to upload this script,\n\nYou will log in as $USER user" 12 78  --title "Upload script" --backtitle "$title" 3>&1 1>&2 2>&3)
			if [ "$?" = "0" ]; then
			{
				login_upload="$ymg_sitecode$end_dns"
				upload_script
			}
			fi
		}
		else
		{	
			main_menu
		}
		fi
		}
	fi

	if [ "$1" = "-u" ] || [ "$1" = "--upload" ]; then
		{
		if [ "$2" != "" ];then
			{
			login_upload=$2
			upload_script
			}
		else
			echo -e "$red \nPlease use destination address : script.sh -i login@IP_ORC $no_color";
		fi
		}
	fi

	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		{ 
			echo -e "\n Without Options : \n\t$Yellow On your computer : $no_color Open a menu to upload the script with Ymagis sitecode"
			echo -e "\t$Yellow On Orchestra : $no_color Open a menu to interact with NBP"		
			echo -e "\n With Options : \n\t$Cyan-u$green login@IP_ORC$no_color or $Cyan--upload$green login@IP_ORC$no_color : Auto upload script on Orchestra"
			echo -e "\tEx: script.sh -u cbeudot@10.149.213.254\n"
			echo -e "\t$Cyan-v$no_color or $Cyan--version$no_color : Print the current version of the script."
			echo -e "\t$Cyan-m$no_color or $Cyan--mtu$green IP_ORC $no_color : Check optimal mtu value for tun1."
			echo -e "\n When you're logged on orchestra : \n"
			echo -e "\t$Cyan-c$no_color or $Cyan--check$no_color : Print result of check configuration in a log file"
			echo -e "\t$Cyan-t$no_color or $Cyan--track_update $green*research*$no_color : List *DCPs*, check their push status, and update them"
			echo -e "\tEx: ./script.sh -t toystory\n"
			echo -e "\t$Cyan-t$no_color or $Cyan--track_update $green playlists $no_color : List last 20 *SPL* in assets-folder, check their push status, and update them"
			echo -e "\tEx: ./script.sh -t playslists\n"
			echo -e "\t$Cyan-s$no_color or $Cyan--show$no_color : Show the push config"
			echo -e "\t$Cyan-f$no_color or $Cyan--ftp$no_color : Connect directly to the library filled for DCPs in push config \n"
			echo -e "$red This is a homemade script, please use it carefully, maybe the developer was drunk when he wrote these lines.$no_color\n"
		}
	fi
	if [ "$1" = "-v" ] || [ "$1" = "--version" ]; then
		{ 
			echo -e "\n$green$title$no_color\n"
		}
	fi

	if [ "$1" = "-c" ] || [ "$1" = "--check" ]; then
		{ 
			check_configuration
			echo -e "$green"
			cat $HOME/log.check.support_nbp
			echo -e "$no_color"
			rm $HOME/log.check.support_nbp
		}
	fi
	if [ "$1" = "-m" ] || [ "$1" = "--mtu" ]; then
		{
		if [ "$2" != "" ];then
			{
			ip_test_mtu=$2
			check_mtu
			}
		else
			echo -e "$red \nPlease add Orchestra IP : script.sh --mtu IP_ORC $no_color";
		fi
		}
	fi
	if [ "$1" = "-t" ] || [ "$1" = "--track_update" ]; then
		{
		if [ "$2" = "playlists" ];then
		{
			echo "ah coucou"
			force_track_update_playlists
		}
		else
		{
			if [ "$2" != "" ] && [ "$2" != "playlists" ];then
				{
				search_area=$2
				force_track_update_dcp
				}
			else
				echo -e "$red \nPlease add dcp_name to list and force versions. $no_color";
			fi
		}
		fi
		}
	fi
	if [ "$1" = "-f" ] || [ "$1" = "--ftp" ]; then
		{ 
			ftp_connect
		}
	fi
	if [ "$1" = "-s" ] || [ "$1" = "--show" ]; then
		{ 
			get_push_config
			#cat $push_config
			whiptail --title "ftp-push.yml" --textbox $push_config --backtitle "$title" 20 60
		}
	fi
}
else
{
	echo -e "\n$red Please don't use this script as root user\n$no_color"
}
fi
