#!/bin/bash

clear
mkdir -p ~/.cloudshell && touch ~/.cloudshell/no-apt-get-warning 
echo "လိုအပ်တဲ့ file များဖည့်နေပါပြီ..."
apt update -y && apt install sudo -y
sudo apt-get update -y --fix-missing && sudo apt-get install wireguard-tools jq wget -y --fix-missing

priv="${1:-$(wg genkey)}"
pub="${2:-$(echo "${priv}" | wg pubkey)}"
api="https://api.cloudflareclient.com/v0i1909051800"
ins() { curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}"; }
sec() { ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"; }
response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")

clear
id=$(echo "$response" | jq -r '.result.id')
token=$(echo "$response" | jq -r '.result.token')
response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')
peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key')
peer_endpoint=$(echo "$response" | jq -r '.result.config.peers[0].endpoint.host')
client_ipv4=$(echo "$response" | jq -r '.result.config.interface.addresses.v4')
client_ipv6=$(echo "$response" | jq -r '.result.config.interface.addresses.v6')

reserved64=$(echo "$response" | jq -r '.result.config.client_id')
reservedHex=$(echo "$reserved64" | base64 -d | hexdump -v -e '/1 "%02x\n"')
reservedDec=$(printf '%s\n' "${reservedHex}" | while read -r hex; do printf "%d, " "0x${hex}"; done)
reservedDec="[${reservedDec%, }]"
reservedHex=$(echo "${reservedHex}" | awk 'BEGIN { ORS=""; print "0x" } { print }')

conf=$(cat <<-EOM
{
  "outbounds":   [
{
"tag": "WARP",
"reserved": ${reservedDec},
"mtu": 1280,
"fake_packets": "5-10",
"fake_packets_size": "40-100",
"fake_packets_delay": "20-250",
"fake_packets_mode": "m4",
"private_key": "${priv}",
"type": "wireguard",
"local_address": ["${client_ipv4}/32", "${client_ipv6}/128"],
"peer_public_key": "${peer_pub}",
"server": "162.159.192.1",
"server_port": 500
}
  ]
}
EOM
)

conf_base64=$(echo -n "${conf}" | base64 -w 0)
echo -e "\n\n\n"
[ -t 1 ] && echo "########## НАЧАЛО КОНФИГА ##########"
echo "${conf}"
[ -t 1 ] && echo "########### КОНЕЦ КОНФИГА ###########"
echo "reserved в знаках:"
echo "\"reserved\": \"${reserved64}\","
echo -e "\n"
echo "တစ်ခါတစ်ရံ အပေါ်မှာပြထားတဲ့ config က မပြည့်စုံတာ ဒါမှမဟုတ် မရှိတော့တာ ဖြစ်နိုင်ပါတယ်၊ ဒါကြောင့် link ကနေ download လုပ်ပြီး သုံးတာက ပိုကောင်းပါတယ်။"
echo -e "\n"
echo "https://immalware.vercel.app/download?filename=WARP.conf&content=${conf_base64}"
echo -e "\n"
echo "Channel သို့ Join ထားပါ: https://t.me/mhwarp"
