#! /bin/bash
ON_THRESHOLD=65
OFF_THRESHOLD=55
ON_THRESHOLD_SET=false
OFF_THRESHOLD_SET=false
DELAY=2
BRIGHTNESS=255
PREEMPT=n
NOLED=n
NOBUTTON=n
EXTCOLOURS=n
EXTRA_ARGS=""

SERVICE_PATH=/etc/systemd/system/pimoroni-fanshim.service

vars=$(getopt -o f:o:d:r:G:R:plbxh --long off-threshold:,on-threshold:,delay:,brightness:,low-temp:,high-temp:,preempt,noled,nobutton,extended-colours,help -- "$@")

USAGE="./install-service.sh --off-threshold <n> --on-threshold <n> --delay <n> --brightness <n> --low-temp <n> --high-temp <n> --venv <python_virtual_environment> (--preempt) (--noled) (--nobutton) (--extended-colours)"

venv_check() {
	PYTHON_BIN=$(which $PYTHON)
	if [[ $VIRTUAL_ENV == "" ]] || [[ $PYTHON_BIN != $VIRTUAL_ENV* ]]; then
		printf "This script should be run in a virtual Python environment.\n"
		exit 1
	fi
}

usage() {
>&2 cat << EOF
$0
    [ -f | --off-threshold <n> ]
    [ -o | --on-threshold <n> ]
    [ -d | --delay <n> ]
    [ -r |--brightness <n> ]
    [ -G | --low-temp <n> ]
    [ -R | --high-temp <n> ]
    [ -p | --preempt ]
    [ -l | --noled ]
    [ -b | --nobutton ]
    [ -x | --extended-colours ]
    [ -h | --help ]
EOF
exit 1
}

check_is_number() {
    if ! [[ $2 =~ ^[0-9]+$ ]] ; then
        printf "error on $1: $2 is not a number\n"; 
        exit 1
    fi
}

get_options() {
    eval set -- "$vars"
    for opt; do
        case "$opt" in
            -f | --off-threshold)
                check_is_number $opt $2
                OFF_THRESHOLD=$2
		        OFF_THRESHOLD_SET=true
                shift 2
                ;;
            -o | --on-threshold)
                check_is_number $opt $2
                ON_THRESHOLD=$2
                ON_THRESHOLD_SET=true
                shift 2
                ;;
            -d | --delay)
                check_is_number $opt $2
                DELAY=$2
                shift 2
                ;;
            -r | --brightness)
                check_is_number $opt $2
                BRIGHTNESS=$2
                shift 2
                ;;
            -G | --low-temp)
                check_is_number $opt $2
                LOW_TEMP=$2
                shift 2
                ;;
            -R | --high-temp)
                check_is_number $opt $2
                HIGH_TEMP=$2
                shift 2
                ;;
            -p | --preempt)
                PREEMPT=y
                shift
                ;;
            -l | --noled)
                NOLED=y
                shift
                ;;
            -b | --nobutton)
                NOBUTTON=y
                shift
                ;;
            -x | --extended-colours)
                EXTCOLOURS=y
                shift
                ;;
            -h | --help)
                usage
                exit 0
        esac
    done
}

set_arguments() {
    if [ "$PREEMPT" == "y" ]; then
        EXTRA_ARGS+=' --preempt'
    fi

    if [ "$NOLED" == "y" ]; then
        EXTRA_ARGS+=' --noled'
    fi

    if [ "$NOBUTTON" == "y" ]; then
	    EXTRA_ARGS+=' --nobutton'
    fi

    if [ "$EXTCOLOURS" == "y" ]; then
        EXTRA_ARGS+=' --extended-colours'
    fi

    if [ "$LOW_TEMP" == "" ]; then
        LOW_TEMP=$OFF_THRESHOLD
    fi

    if [ "$HIGH_TEMP" == "" ]; then
        HIGH_TEMP=$ON_THRESHOLD
    fi
}

#venv_check

get_options
set_arguments

printf "Installing fanshim service \n"
cat << EOF
Setting up with:
Off Threshold:    $OFF_THRESHOLD °C
On Threshold:     $ON_THRESHOLD °C
Low Temp:         $LOW_TEMP °C
High Temp:        $HIGH_TEMP °C
Delay:            $DELAY seconds
Preempt:          $PREEMPT
Disable LED:      $NOLED
Disable Button:   $NOBUTTON
Brightness:       $BRIGHTNESS
Extended Colours: $EXTCOLOURS
EOF

read -r -d '' UNIT_FILE << EOF
[Unit]
Description=Fan Shim Service
After=multi-user.target

[Service]
Type=simple
WorkingDirectory=$(pwd)
ExecStart=source $VIRTUAL_ENV/bin/activate;$PYTHON $(pwd)/automatic.py --on-threshold $ON_THRESHOLD --off-threshold $OFF_THRESHOLD --low-temp $LOW_TEMP --high-temp $HIGH_TEMP --delay $DELAY --brightness $BRIGHTNESS $EXTRA_ARGS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

printf "\nInstalling service to: $SERVICE_PATH\n"
echo "$UNIT_FILE" > $SERVICE_PATH
systemctl daemon-reload
systemctl enable --no-pager pimoroni-fanshim.service
systemctl restart --no-pager pimoroni-fanshim.service
systemctl status --no-pager pimoroni-fanshim.service

printf "done"