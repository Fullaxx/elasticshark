# elasticshark
Sift Packets with Elasticsearch

## Build the image
```
docker build -t fullaxx/elasticshark .
```

## Run the image
```
docker run -d --rm \
-h elasticshark \
--name elasticshark \
--cap-add SYS_TIME \
--memory 4G \
--cpuset-cpus=0-1 \
--ulimit nofile=65535:65535 \
--ulimit memlock=-1:-1 \
-p 9200:9200 \
-p 5601:5601 \
-e "KBN_PATH_CONF=/usr/share/kibana/config" \
-e "bootstrap.memory_lock=true" \
fullaxx/elasticshark
```

## Compile the tshark EK converter
```
cd src
./compile.sh
```

## Helpful commands
```
tshark -G elastic-mapping | less
sudo tshark -i eth0 -T ek | ./pretty.exe
```