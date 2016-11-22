#source this, then run watchdog in rootdir of scraping webcomic
watchdog()
{

local watchdog_stop=1
local count=0
local scrape_process=webcomic_walker

while [ ${watchdog_stop:=1} = 1 ];
	 do 
		filetype=$(file --mime-type out/$(ls --sort=time -r out/ | tail -n1) | grep -Ev -e ': image/' -e ': inode/')
			if ! [ "${filetype}ERROR" = "ERROR" ];
				 then 
					pkill $(pgrep -a bash | grep webcomic_walker | cut -d\  -f 1)
					echo killed webcomic_walker.sh
					break
				 else
					count=$((${count} + 1))
					echo scrape has not stopped ${count}
			fi

			if [ "$(pgrep -a ${scrape_process} | cut -d\  -f 1)DONE" = "DONE" ];
				then
					watchdog_stop=0
			fi
	ls out | tail -n 10; echo END OF DIR; echo .;
	 sleep 2
done

echo Watchdog stopped after $((${count}*2)) seconds

}
