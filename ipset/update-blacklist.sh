#!/usr/bin/env bash
#
# Use update-blacklist.sh <configuration file>
# Ex: update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf
#
clear

function exists() { command -v "$1" >/dev/null 2>&1 ; }

if [[ -z "$1" ]]; then
  echo "Erro: especifique um arquivo de configuração, por exemplo. $0 /etc/ipset-blacklist/ipset-blacklist.conf"
  exit 1
fi

# shellcheck source=ipset-blacklist.conf
if ! source "$1"; then
  echo "Erro: não é possível carregar o arquivo de configuração $1"
  exit 1
fi

if ! exists curl && exists egrep && exists grep && exists ipset && exists iptables && exists sed && exists sort && exists wc ; then
  echo >&2 "Erro: a pesquisa de PATH não consegue encontrar executáveis entre: curl egrep grep ipset iptables sed sort wc"
  exit 1
fi

DO_OPTIMIZE_CIDR=no
if exists iprange && [[ ${OPTIMIZE_CIDR:-yes} != no ]]; then
  DO_OPTIMIZE_CIDR=yes
fi

############################################################################################################
if [[ ! -d $(dirname "$IP_COUNTRIES") || ! -d $(dirname "$IP_COUNTRIES_RESTORE") ]]; then
  echo >&2 "Error: missing directory(s): $(dirname "$IP_COUNTRIES" "$IP_COUNTRIES_RESTORE"|sort -u)"
  exit 1
fi
##########################
if [[ ! -d $(dirname "$IP_WHITELISTS") || ! -d $(dirname "$IP_WHITELISTS_RESTORE") ]]; then
  echo >&2 "Error: missing directory(s): $(dirname "$IP_WHITELISTS" "$IP_WHITELISTS_RESTORE"|sort -u)"
  exit 1
fi
##########################
if [[ ! -d $(dirname "$IP_BLACKLIST") || ! -d $(dirname "$IP_BLACKLIST_RESTORE") ]]; then
  echo >&2 "Error: missing directory(s): $(dirname "$IP_BLACKLIST" "$IP_BLACKLIST_RESTORE"|sort -u)"
  exit 1
fi

############################################################################################################
# crie o ipset se necessário (ou aborte se não existir e FORCE = não)
if ! ipset list -n|command grep -q "$IPSET_COUNTRIES_NAME"; then
  if [[ ${FORCE:-no} != yes ]]; then
    echo >&2 "Error: ipset does not exist yet, add it using:"
    echo >&2 "# ipset create $IPSET_COUNTRIES_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}"
    exit 1
  fi
  if ! ipset create "$IPSET_COUNTRIES_NAME" -exist hash:net family inet hashsize "${HASHSIZE:-16384}" maxelem "${MAXELEM:-65536}"; then
    echo >&2 "Error: while creating the initial ipset"
    exit 1
  fi
fi
##########################
# crie o ipset se necessário (ou aborte se não existir e FORCE = não)
if ! ipset list -n|command grep -q "$IPSET_WHITELISTS_NAME"; then
  if [[ ${FORCE:-no} != yes ]]; then
    echo >&2 "Error: ipset does not exist yet, add it using:"
    echo >&2 "# ipset create $IPSET_WHITELISTS_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}"
    exit 1
  fi
  if ! ipset create "$IPSET_WHITELISTS_NAME" -exist hash:net family inet hashsize "${HASHSIZE:-16384}" maxelem "${MAXELEM:-65536}"; then
    echo >&2 "Error: while creating the initial ipset"
    exit 1
  fi
fi
##########################
# crie o ipset se necessário (ou aborte se não existir e FORCE = não)
if ! ipset list -n|command grep -q "$IPSET_BLACKLIST_NAME"; then
  if [[ ${FORCE:-no} != yes ]]; then
    echo >&2 "Error: ipset does not exist yet, add it using:"
    echo >&2 "# ipset create $IPSET_BLACKLIST_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}"
    exit 1
  fi
  if ! ipset create "$IPSET_BLACKLIST_NAME" -exist hash:net family inet hashsize "${HASHSIZE:-16384}" maxelem "${MAXELEM:-65536}"; then
    echo >&2 "Error: while creating the initial ipset"
    exit 1
  fi
fi

############################################################################################################
# crie a ligação iptables se necessário (ou aborte se não existir e FORCE = não)
if ! iptables -nvL INPUT|command grep -q "match-set $IPSET_COUNTRIES_NAME"; then
  # we may also have assumed that INPUT rule n°1 is about packets statistics (traffic monitoring)
  if [[ ${FORCE:-no} != yes ]]; then
    echo >&2 "Error: iptables does not have the needed ipset INPUT rule, add it using:"
    echo >&2 "# iptables -I INPUT ${IPTABLES_IPSET_RULE_NUMBER:-1} -m set --match-set $IPSET_COUNTRIES_NAME src -j DROP"
    exit 1
  fi
  if ! iptables -I INPUT "${IPTABLES_IPSET_RULE_NUMBER:-1}" -m set --match-set "$IPSET_COUNTRIES_NAME" src -j DROP; then
    echo >&2 "Error: while adding the --match-set ipset rule to iptables"
    exit 1
  fi
fi
##########################
# crie a ligação iptables se necessário (ou aborte se não existir e FORCE = não)
if ! iptables -nvL INPUT|command grep -q "match-set $IPSET_WHITELISTS_NAME"; then
  # we may also have assumed that INPUT rule n°1 is about packets statistics (traffic monitoring)
  if [[ ${FORCE:-no} != yes ]]; then
    echo >&2 "Error: iptables does not have the needed ipset INPUT rule, add it using:"
    echo >&2 "# iptables -I INPUT ${IPTABLES_IPSET_RULE_NUMBER:-1} -m set --match-set $IPSET_WHITELISTS_NAME src -j ACCEPT"
    exit 1
  fi
  if ! iptables -I INPUT "${IPTABLES_IPSET_RULE_NUMBER:-1}" -m set --match-set "$IPSET_WHITELISTS_NAME" src -j ACCEPT; then
    echo >&2 "Error: while adding the --match-set ipset rule to iptables"
    exit 1
  fi
fi
##########################
# crie a ligação iptables se necessário (ou aborte se não existir e FORCE = não)
if ! iptables -nvL INPUT|command grep -q "match-set $IPSET_BLACKLIST_NAME"; then
  # we may also have assumed that INPUT rule n°1 is about packets statistics (traffic monitoring)
  if [[ ${FORCE:-no} != yes ]]; then
    echo >&2 "Error: iptables does not have the needed ipset INPUT rule, add it using:"
    echo >&2 "# iptables -I INPUT ${IPTABLES_IPSET_RULE_NUMBER:-1} -m set --match-set $IPSET_BLACKLIST_NAME src -j DROP"
    exit 1
  fi
  if ! iptables -I INPUT "${IPTABLES_IPSET_RULE_NUMBER:-1}" -m set --match-set "$IPSET_BLACKLIST_NAME" src -j DROP; then
    echo >&2 "Error: while adding the --match-set ipset rule to iptables"
    exit 1
  fi
fi

############################################################################################################
IP_COUNTRIES_TMP=$(mktemp)
for i in "${COUNTRIES[@]}"
do
  IP_TMP_COUNTRIES=$(mktemp)
  (( HTTP_RC=$(curl -L -A "blacklist-update/script/github" --connect-timeout 10 --max-time 10 -o "$IP_TMP_COUNTRIES" -s -w "%{http_code}" "$i") ))
  if (( HTTP_RC == 200 || HTTP_RC == 302 || HTTP_RC == 0 )); then # "0" because file:/// returns 000
    command grep -Po '^(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?' "$IP_TMP_COUNTRIES" | sed -r 's/^0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)$/\1.\2.\3.\4/' >> "$IP_COUNTRIES_TMP"
    [[ ${VERBOSE:-yes} == yes ]] && echo -n "."
  elif (( HTTP_RC == 503 )); then
    echo -e "\\nIndisponível (${HTTP_RC}): $i"
  else
    echo >&2 -e "\\nAviso: curl retornou código de resposta HTTP $HTTP_RC para URL $i"
  fi
  rm -f "$IP_TMP_COUNTRIES"
done

# sort -nu não funciona como esperado
sed -r -e '/^(0\.0\.0\.0|10\.|127\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168\.|22[4-9]\.|23[0-9]\.)/d' "$IP_COUNTRIES_TMP"|sort -n|sort -mu >| "$IP_COUNTRIES"
if [[ ${DO_OPTIMIZE_CIDR} == yes ]]; then
  if [[ ${VERBOSE:-no} == yes ]]; then
    echo -e "\\nEndereços antes da otimização CIDR: $(wc -l "$IP_COUNTRIES" | cut -d' ' -f1)"
  fi
  < "$IP_COUNTRIES" iprange --optimize - > "$IP_COUNTRIES_TMP" 2>/dev/null
  if [[ ${VERBOSE:-no} == yes ]]; then
    echo "Endereços após otimização CIDR:  $(wc -l "$IP_COUNTRIES_TMP" | cut -d' ' -f1)"
  fi
  cp "$IP_COUNTRIES_TMP" "$IP_COUNTRIES"
fi
rm -f "$IP_COUNTRIES_TMP"
##########################
IP_WHITELISTS_TMP=$(mktemp)
for i in "${WHITELISTS[@]}"
do
  IP_TMP_WHITELISTS=$(mktemp)
  (( HTTP_RC=$(curl -L -A "blacklist-update/script/github" --connect-timeout 10 --max-time 10 -o "$IP_TMP_WHITELISTS" -s -w "%{http_code}" "$i") ))
  if (( HTTP_RC == 200 || HTTP_RC == 302 || HTTP_RC == 0 )); then # "0" because file:/// returns 000
    command grep -Po '^(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?' "$IP_TMP_WHITELISTS" | sed -r 's/^0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)$/\1.\2.\3.\4/' >> "$IP_WHITELISTS_TMP"
    [[ ${VERBOSE:-yes} == yes ]] && echo -n "."
  elif (( HTTP_RC == 503 )); then
    echo -e "\\nIndisponível (${HTTP_RC}): $i"
  else
    echo >&2 -e "\\nAviso: curl retornou código de resposta HTTP $HTTP_RC para URL $i"
  fi
  rm -f "$IP_TMP_WHITELISTS"
done

# sort -nu não funciona como esperado
sed -r -e '/^(0\.0\.0\.0|10\.|127\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168\.|22[4-9]\.|23[0-9]\.)/d' "$IP_WHITELISTS_TMP"|sort -n|sort -mu >| "$IP_WHITELISTS"
if [[ ${DO_OPTIMIZE_CIDR} == yes ]]; then
  if [[ ${VERBOSE:-no} == yes ]]; then
    echo -e "\\nEndereços antes da otimização CIDR: $(wc -l "$IP_WHITELISTS" | cut -d' ' -f1)"
  fi
  < "$IP_WHITELISTS" iprange --optimize - > "$IP_WHITELISTS_TMP" 2>/dev/null
  if [[ ${VERBOSE:-no} == yes ]]; then
    echo "Endereços após otimização CIDR:  $(wc -l "$IP_WHITELISTS_TMP" | cut -d' ' -f1)"
  fi
  cp "$IP_WHITELISTS_TMP" "$IP_WHITELISTS"
fi
rm -f "$IP_WHITELISTS_TMP"
##########################
IP_BLACKLIST_TMP=$(mktemp)
for i in "${BLACKLISTS[@]}"
do
  IP_TMP_BLACKLIST=$(mktemp)
  (( HTTP_RC=$(curl -L -A "blacklist-update/script/github" --connect-timeout 10 --max-time 10 -o "$IP_TMP_BLACKLIST" -s -w "%{http_code}" "$i") ))
  if (( HTTP_RC == 200 || HTTP_RC == 302 || HTTP_RC == 0 )); then # "0" because file:/// returns 000
    command grep -Po '^(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?' "$IP_TMP_BLACKLIST" | sed -r 's/^0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)$/\1.\2.\3.\4/' >> "$IP_BLACKLIST_TMP"
    [[ ${VERBOSE:-yes} == yes ]] && echo -n "."
  elif (( HTTP_RC == 503 )); then
    echo -e "\\nIndisponível (${HTTP_RC}): $i"
  else
    echo >&2 -e "\\nAviso: curl retornou código de resposta HTTP $HTTP_RC para URL $i"
  fi
  rm -f "$IP_TMP_BLACKLIST"
done

# sort -nu não funciona como esperado
sed -r -e '/^(0\.0\.0\.0|10\.|127\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168\.|22[4-9]\.|23[0-9]\.)/d' "$IP_BLACKLIST_TMP"|sort -n|sort -mu >| "$IP_BLACKLIST"
if [[ ${DO_OPTIMIZE_CIDR} == yes ]]; then
  if [[ ${VERBOSE:-no} == yes ]]; then
    echo -e "\\nEndereços antes da otimização CIDR: $(wc -l "$IP_BLACKLIST" | cut -d' ' -f1)"
  fi
  < "$IP_BLACKLIST" iprange --optimize - > "$IP_BLACKLIST_TMP" 2>/dev/null
  if [[ ${VERBOSE:-no} == yes ]]; then
    echo "Endereços após otimização CIDR:  $(wc -l "$IP_BLACKLIST_TMP" | cut -d' ' -f1)"
  fi
  cp "$IP_BLACKLIST_TMP" "$IP_BLACKLIST"
fi
rm -f "$IP_BLACKLIST_TMP"

############################################################################################################
# família = inet apenas para IPv4
cat >| "$IP_COUNTRIES_RESTORE" <<EOF
create $IPSET_TMP_COUNTRIES_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}
create $IPSET_COUNTRIES_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}
EOF

# pode ser IPv4 incluindo notação de máscara de rede
# IPv6 ? -e "s/^([0-9a-f:./]+).*/add $IPSET_TMP_COUNTRIES_NAME \1/p" \ IPv6
sed -rn -e '/^#|^$/d' \
  -e "s/^([0-9./]+).*/add $IPSET_TMP_COUNTRIES_NAME \\1/p" "$IP_COUNTRIES" >> "$IP_COUNTRIES_RESTORE"

cat >> "$IP_COUNTRIES_RESTORE" <<EOF
swap $IPSET_COUNTRIES_NAME $IPSET_TMP_COUNTRIES_NAME
destroy $IPSET_TMP_COUNTRIES_NAME
EOF
##########################
# família = inet apenas para IPv4
cat >| "$IP_WHITELISTS_RESTORE" <<EOF
create $IPSET_TMP_WHITELISTS_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}
create $IPSET_WHITELISTS_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}
EOF

# pode ser IPv4 incluindo notação de máscara de rede
# IPv6 ? -e "s/^([0-9a-f:./]+).*/add $IPSET_TMP_WHITELISTS_NAME \1/p" \ IPv6
sed -rn -e '/^#|^$/d' \
  -e "s/^([0-9./]+).*/add $IPSET_TMP_WHITELISTS_NAME \\1/p" "$IP_WHITELISTS" >> "$IP_WHITELISTS_RESTORE"

cat >> "$IP_WHITELISTS_RESTORE" <<EOF
swap $IPSET_WHITELISTS_NAME $IPSET_TMP_WHITELISTS_NAME
destroy $IPSET_TMP_WHITELISTS_NAME
EOF
##########################
# família = inet apenas para IPv4
cat >| "$IP_BLACKLIST_RESTORE" <<EOF
create $IPSET_TMP_BLACKLIST_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}
create $IPSET_BLACKLIST_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}
EOF

# pode ser IPv4 incluindo notação de máscara de rede
# IPv6 ? -e "s/^([0-9a-f:./]+).*/add $IPSET_TMP_BLACKLIST_NAME \1/p" \ IPv6
sed -rn -e '/^#|^$/d' \
  -e "s/^([0-9./]+).*/add $IPSET_TMP_BLACKLIST_NAME \\1/p" "$IP_BLACKLIST" >> "$IP_BLACKLIST_RESTORE"

cat >> "$IP_BLACKLIST_RESTORE" <<EOF
swap $IPSET_BLACKLIST_NAME $IPSET_TMP_BLACKLIST_NAME
destroy $IPSET_TMP_BLACKLIST_NAME
EOF

############################################################################################################
ipset -file  "$IP_COUNTRIES_RESTORE" restore
if [[ ${VERBOSE:-no} == yes ]]; then
  echo
  echo "Endereços dos Paises em Blacklist encontrados: $(wc -l "$IP_COUNTRIES" | cut -d' ' -f1)"
fi
##########################
ipset -file  "$IP_WHITELISTS_RESTORE" restore
if [[ ${VERBOSE:-no} == yes ]]; then
  echo
  echo "Endereços dos Paises em Whitelist encontrados: $(wc -l "$IP_WHITELISTS" | cut -d' ' -f1)"
fi
##########################
ipset -file  "$IP_BLACKLIST_RESTORE" restore
if [[ ${VERBOSE:-no} == yes ]]; then
  echo
  echo "Endereços Mundial em Blacklist encontrados $(wc -l "$IP_BLACKLIST" | cut -d' ' -f1)"
fi
