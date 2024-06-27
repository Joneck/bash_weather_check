#!/bin/bash

function show_help {
    	echo "Użycie: $0 nazwa_miejscowości"
    	echo "Podaje dane pogodowe odczytane z najbliższej stacji meteorologicznej"
    	echo
    	echo "  -h, --help  wyświetla ten komunikat i kończy działanie"
	echo "  -debug, --verbose wyświetla dane na temat działania programu"
	echo
}

if [[ $1 == "-h" ]] || [[ $1 == "--help" ]]; then
    show_help
    exit 0
fi

DEBUG=0
if [[ $1 == "--debug" ]] || [[ $1 == "--verbose" ]]; then
    DEBUG=1
    shift
fi

if [ -f .mymeteorc ]; then
    source ~/.mymeteorc
else
    DEFAULT_CITY="Poznan"
fi


VAR1=${1:-$DEFAULT_CITY}
if [ $DEBUG -eq 1 ]; then
	echo "Pobieram dane podanej miejscowości"
fi
curl "https://nominatim.openstreetmap.org/search?&format=jsonv2" --get --data-urlencode "q=$VAR1" --no-progress-meter | jq '.[0]' > ~/.cache/miasto.json
lat=$(cat ~/.cache/miasto.json | jq '.lat' -r | bc)
lon=$(cat ~/.cache/miasto.json | jq '.lon' -r | bc)

if [ ! -f ~/.cache/stacje.json ]; then
	if [ $DEBUG -eq 1 ]; then
        	echo "Pobieram dane pogodowe"
        fi
	curl "https://danepubliczne.imgw.pl/api/data/synop" --no-progress-meter > ~/.cache/stacje.json
else

	DATE=$(cat ~/.cache/stacje.json | jq ".[0].data_pomiaru" -r)
	TODAY=$(date +%Y-%m-%d)

	if [ ! "$DATE" == "$TODAY" ]; then
		if [ $DEBUG -eq 1 ]; then
                	echo "Pobieram dane pogodowe"
                fi
		curl "https://danepubliczne.imgw.pl/api/data/synop" --no-progress-meter > ~/.cache/stacje.json

	else
		UPDATE=$(cat ~/.cache/stacje.json | jq ".[0].godzina_pomiaru" -r)
		TIME=$(date +%H)

		if [ ! $TIME == $UPDATE ]; then
			if [ $DEBUG -eq 1 ]; then
				echo "Pobieram dane pogodowe"
			fi
			curl "https://danepubliczne.imgw.pl/api/data/synop" --no-progress-meter > ~/.cache/stacje.json
		fi
	fi
fi

if [ ! -f ~/.cache/miasta.json ]; then

if [ $DEBUG -eq 1 ]; then
    echo "Pobieram listę miast"
fi

echo "[" > ~/.cache/miasta.json

for i in {0..61} 
do
var=$(cat ~/.cache/stacje.json | jq -r ".[$i].stacja")

curl_output=$(curl "https://nominatim.openstreetmap.org/search?&format=jsonv2" --get --data-urlencode "q=$var" --no-progress-meter 2>&1)

if [ $? -ne 0 ]; then
    echo
    echo "Błąd: Nie udało się pobrać danych z https://nominatim.openstreetmap.org/search?&format=jsonv2"
    if [ $DEBUG -eq 1 ]; then
        echo "Szczegóły błędu: $curl_output"
    fi
    rm ~/.cache/miasta.json
    exit 1
else
    echo $curl_output | jq '.[0]' >> ~/.cache/miasta.json
fi

if [ $i -ne 61 ]; then
sleep 4
printf "," >>~/.cache/miasta.json
fi

if [ $DEBUG -eq 1 ]; then
    printf "\rPobrano $((i+1)) z 62"
fi
done

echo "]" >> ~/.cache/miasta.json

fi
echo
if [ $DEBUG -eq 1 ]; then
    echo "Porównuję odległości od wybranej miejscowosci"
fi


index=0

lat1=$(cat ~/.cache/miasta.json | jq -r '.[0].lat' | bc)
lon1=$(cat ~/.cache/miasta.json | jq -r '.[0].lon' | bc)

dlat=$(echo $lat - $lat1 | bc -l)
dlon=$(echo $lon - $lon1 | bc -l)

dlat=$(echo $dlat*$dlat | bc -l)
dlon=$(echo $dlon*$dlon | bc -l)

min=$(echo $dlat + $dlon | bc -l)

for i in {1..61}
do
lat1=$(cat ~/.cache/miasta.json | jq ".[$i].lat" -r | bc)
lon1=$(cat ~/.cache/miasta.json | jq ".[$i].lon" -r | bc)

dlat=$(echo $lat - $lat1 | bc -l)
dlon=$(echo $lon - $lon1 | bc -l)

dlat=$(echo $dlat*$dlat | bc -l)
dlon=$(echo $dlon*$dlon | bc -l)

temp=$(echo $dlat + $dlon | bc -l)

if (( $(echo "$temp < $min" | bc -l) )); then
min=$temp
index=$i
fi

if [ $DEBUG -eq 1 ]; then
    printf "\rPorównano $((i+1)) z 62"
fi

done
printf "\n\n"

if [ $DEBUG -eq 1 ]; then
    echo "Podaję odpowiedź"
fi

echo $(cat ~/.cache/stacje.json | jq -r ".[$index].stacja") / $(cat ~/.cache/stacje.json | jq -r ".[$index].data_pomiaru") $(cat ~/.cache/stacje.json | jq -r ".[$index].godzina_pomiaru"):00
echo $(cat ~/.cache/stacje.json | jq ".[$index].temperatura" -r) °C
echo $(cat ~/.cache/stacje.json | jq ".[$index].predkosc_wiatru" -r) m/s
echo $(cat ~/.cache/stacje.json | jq ".[$index].kierunek_wiatru" -r) °
echo $(cat ~/.cache/stacje.json | jq ".[$index].wilgotnosc_wzgledna" -r) %
echo $(cat ~/.cache/stacje.json | jq ".[$index].suma_opadu" -r) mm
echo $(cat ~/.cache/stacje.json | jq ".[$index].cisnienie" -r) hPa

