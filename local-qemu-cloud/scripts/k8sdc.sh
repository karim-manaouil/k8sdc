#!/bin/bash

RAM=256 	# Default RAM in MB
DISK=5		# Default disk size in GB
VCPU=2 		# Default number of CPUs

parse_cmdline() 
{
    while (( $# )); do
        case $1 in
            --name)				
                NAME="$2"
                shift 2
                ;;
            --ci-key)
                CI_KEY="$2"
                shift 2
                ;;
            --nat)
              	NAT="$2"
			   	shift 2	
                ;;
            --br)
               	BR="$2" 
                shift 2
                ;;
            --ram)
                RAM="$2"
                shift 2
                ;;
            --disk)
                DISK="$2"
                shift 2
                ;;
            --vcpu)
                VCPU="$2"
                shift 2
                ;;
            *)
               echo "unknown option $1"
			   exit -1
		esac
	done
}


main() 
{
	parse_cmdline $@
	if [ ! -v NAME ] || [ ! -v CI_KEY ] || [ ! -v NAT ]; then
			echo "Missing arguments: --name, --ci-key and --nat must be provided"
			exit -1
	fi

	./scripts/build.sh $NAME $CI_KEY $NAT ${BR:-"NONE"} $RAM $DISK $VCPU	
}

main $@

