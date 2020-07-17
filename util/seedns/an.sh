#/bin/bash

HTTP() {
    ms=()
    us=()

    for v in $(grep -v "Running" $1 | grep http | cut -d'=' -f2); do 
        if [ $(echo $v | grep -c "ms") -ge 1 ]; 
        then 
            lt=$(echo $v | sed 's/ms//g')
            lt=$(python -c "print($lt*1000)")
            ms+=("$lt")
        else
            lt=$(echo $v | sed 's/µs//g')
            us+=("$lt")
        fi; 
    done

    echo "${ms[@]}  ${us[@]}"

}

DNS() {
    ms=()
    us=()

    for v in $(grep -v "Running" baseline | grep time | sed 's/addr=/addr:/g' | cut -d'=' -f2); do
      if [ $(echo $v | grep -c "ms") -ge 1 ];
      then
          lt=$(echo $v | sed 's/ms//g')
          lt=$(python -c "print($lt*1000)")
          ms+=("$lt")
      else
          lt=$(echo $v | sed 's/µs//g')
          us+=("$lt")
      fi;
    done

    echo "${ms[@]}  ${us[@]}"
}
    
main() {
    HTTP $@
    DNS $@
}

main $@
