#/bin/bash


if [[ $EUID -ne 0 ]]; then
    echo "You must be root to run this script"
    exit 1
fi

S1="veth-client1"
S2="veth-client2"
S1M="veth-firewall1"
S2M="veth-firewall2"
M2R1="veth-firewall3"
H2F="veth-firewall0"
F="veth0"
R1="veth-server"

NS_SND1="client1"
NS_SND2="client2"
NS_RCV="server"
NS_MID="firewall"


#Create network namespaces
sudo ip netns add $NS_SND1
sudo ip netns add $NS_SND2
sudo ip netns add $NS_RCV
sudo ip netns add $NS_MID


#Create veth pairs
sudo ip link add $S1 type veth peer name $S1M
sudo ip link add $S2 type veth peer name $S2M
sudo ip link add $M2R1 type veth peer name $R1
sudo ip link add $H2F type veth peer


#Bring up 
sudo ip link set dev $S1 up
sudo ip link set dev $S1M up
sudo ip link set dev $M2R1 up
sudo ip link set dev $R1 up
sudo ip link set dev $S2 up
sudo ip link set dev $S2M up

sudo ip link set dev $F up
sudo ip link set dev $H2F up


#Set interfaces to the namespace
sudo ip link set $S1 netns $NS_SND1
sudo ip link set $S1M netns $NS_MID
sudo ip link set $S2 netns $NS_SND2
sudo ip link set $S2M netns $NS_MID
sudo ip link set $M2R1 netns $NS_MID
sudo ip link set $R1 netns $NS_RCV
sudo ip link set $H2F netns $NS_MID


#Bring up lo interface in namespaces
sudo ip netns exec $NS_SND1 ip link set dev lo up
sudo ip netns exec $NS_RCV ip link set dev lo up
sudo ip netns exec $NS_MID ip link set dev lo up
sudo ip netns exec $NS_SND2 ip link set dev lo up

#Bring up interface in namespace and link address
sudo ip netns exec $NS_SND1 ip link set dev $S1 up
sudo ip netns exec $NS_SND1 ip addr add 192.0.2.10/26 dev $S1

sudo ip netns exec $NS_SND2 ip link set dev $S2 up
sudo ip netns exec $NS_SND2 ip addr add 192.0.2.70/26 dev $S2

sudo ip netns exec $NS_RCV ip link set dev $R1 up
sudo ip netns exec $NS_RCV ip addr add 192.0.2.130/26 dev $R1

sudo ip netns exec $NS_MID ip link set dev $S1M up
sudo ip netns exec $NS_MID ip addr add 192.0.2.200/26 dev $S1M

sudo ip netns exec $NS_MID ip link set dev $S2M up
sudo ip netns exec $NS_MID ip addr add 192.0.2.201/26 dev $S2M

sudo ip netns exec $NS_MID ip link set dev $M2R1 up
sudo ip netns exec $NS_MID ip addr add 192.0.2.202/26 dev $M2R1

sudo ip netns exec $NS_MID ip link set dev $H2F up
sudo ip netns exec $NS_MID ip addr add 192.0.2.203/26 dev $H2F

sudo ip link set dev $F up
sudo ip addr add 192.0.2.204/26 dev $F



#Add ip routes
sudo ip netns exec $NS_SND1 ip route add 192.0.2.200 dev $S1
sudo ip netns exec $NS_SND1 ip route add 192.0.2.192/26 via 192.0.2.200 dev $S1
sudo ip netns exec $NS_SND1 ip route add 192.0.2.128/26 via 192.0.2.200 dev $S1

sudo ip netns exec $NS_SND2 ip route add 192.0.2.201 dev $S2
sudo ip netns exec $NS_SND2 ip route add 192.0.2.192/26 via 192.0.2.201 dev $S2
sudo ip netns exec $NS_SND2 ip route add 192.0.2.128/26 via 192.0.2.201 dev $S2

sudo ip netns exec $NS_RCV ip route add 192.0.2.202 dev $R1
sudo ip netns exec $NS_RCV ip route add 192.0.2.192/26 via 192.0.2.202 dev $R1
sudo ip netns exec $NS_RCV ip route add 192.0.2.0/26 via 192.0.2.202 dev $R1
sudo ip netns exec $NS_RCV ip route add 192.0.2.64/26 via 192.0.2.202 dev $R1

sudo ip netns exec $NS_MID ip route add 192.0.2.10 dev $S1M
sudo ip netns exec $NS_MID ip route add 192.0.2.0/26 via 192.0.2.10 dev $S1M
sudo ip netns exec $NS_MID ip route add 192.0.2.128/26 via 192.0.2.10 dev $S1M

sudo ip netns exec $NS_MID ip route add 192.0.2.70 dev $S2M
sudo ip netns exec $NS_MID ip route add 192.0.2.64/26 via 192.0.2.70 dev $S2M
sudo ip netns exec $NS_MID ip route add 192.0.2.128/26 via 192.0.2.70 dev $S2M

sudo ip netns exec $NS_MID ip route add 192.0.2.130 dev $M2R1
sudo ip netns exec $NS_MID ip route add 192.0.2.128/26 via 192.0.2.130 dev $M2R1
sudo ip netns exec $NS_MID ip route add 192.0.2.64/26 via 192.0.2.130 dev $M2R1
sudo ip netns exec $NS_MID ip route add 192.0.2.0/26 via 192.0.2.130 dev $M2R1



sudo ip netns exec $NS_MID ip route add 192.0.2.204 dev $H2F

sudo ip route add 192.0.2.203 dev $F
sudo ip route add 192.0.2.0/26 via 192.0.2.203 dev $F
sudo ip route add 192.0.2.64/26 via 192.0.2.203 dev $F
sudo ip route add 192.0.2.128/26 via 192.0.2.203 dev $F


sudo ip netns exec $NS_MID sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec $NS_SND1 sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec $NS_SND2 sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec $NS_RCV sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.ip_forward=1


sudo ip netns exec $NS_MID iptables -A INPUT -i veth-firewall1 -s 192.0.2.10 -p icmp -j REJECT
sudo ip netns exec $NS_MID iptables -A OUTPUT -o veth-firewall1 -s 192.0.2.10 -p icmp -j REJECT
sudo ip netns exec $NS_MID iptables -A FORWARD -s 192.0.2.10 -p tcp -j REJECT

sudo ip netns exec $NS_SND1 ip route add default via 192.0.2.200 dev $S1M
sudo ip netns exec $NS_RCV ip route add default via 192.0.2.202 dev $R1
sudo ip netns exec $NS_SND2 ip route add default via 192.0.2.201 dev $S2M
sudo ip netns exec $NS_MID ip route add default via 192.0.2.204 dev $H2F

sudo iptables -A FORWARD -o eno1 -i veth0 -j ACCEPT
sudo iptables -A FORWARD -i eno1 -o veth0 -j ACCEPT

sudo iptables -t nat -A POSTROUTING -s 192.0.2.0/26 -o eno1 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -s 192.0.2.64/26 -o eno1 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -s 192.0.2.128/26 -o eno1 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -s 192.0.2.192/26 -o eno1 -j MASQUERADE




















