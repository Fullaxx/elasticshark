# tshark EK converter

## Compile the code
```
./compile.sh
```

## Convert tshark output
```
tshark -r test.pcap -T ek |               ./ek2es7.exe
tshark -r test.pcap -T ek | INDEX=packets ./ek2es7.exe
```

# Upload pcap file
```
PASS=<MYPASSWORD> ./upload.sh packets test.pcap
```
