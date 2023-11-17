## Fork Project of https://github.com/trick77/ipset-blacklist

## Quick start for Debian/Ubuntu/CentOS based installations

1. `wget -O /usr/local/sbin/update-blacklist.sh https://raw.githubusercontent.com/thytetgc/IPSet/main/ipset/update-blacklist.sh`
2. `chmod +x /usr/local/sbin/update-blacklist.sh`
3. `mkdir -p /etc/ipset-blacklist ; wget -O /etc/ipset-blacklist/ipset-blacklist.conf https://raw.githubusercontent.com/thytetgc/IPSet/main/ipset/ipset-blacklist.conf`
4. Modify `ipset-blacklist.conf` according to your needs. Per default, the blacklisted IP addresses will be saved to `/etc/ipset-blacklist/ip-blacklist.restore`
5. `apt-get install ipset` or `yum install ipset`
6. Create the ipset blacklist and insert it into your iptables input filter (see below). After proper testing, make sure to persist it in your firewall script or similar or the rules will be lost after the next reboot.
7. Auto-update the blacklist using a cron job

## First run, create the list

to generate the `/etc/ipset-blacklist/ip-blacklist.restore` and `/etc/ipset-blacklist/ip-countrie.restore`:

```sh
/usr/local/sbin/update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf
```

## iptables filter rule

```sh
# Enable blacklists
ipset restore < /etc/ipset-blacklist/ip-blacklist.restore
iptables -I INPUT 1 -m set --match-set blacklist src -j DROP

# Enable countries
ipset restore < /etc/ipset-blacklist/ip-countrie.restore
iptables -I INPUT 1 -m set --match-set countrie src -j DROP
```

Make sure to run this snippet in a firewall script or just insert it to `/etc/rc.local`.

## Cron job

In order to auto-update the blacklist, copy the following code into `/etc/cron.d/update-blacklist`. Don't update the list too often or some blacklist providers will ban your IP address. Once a day should be OK though.

```sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
33 23 * * *      root /usr/local/sbin/update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf
```

## Check for dropped packets

Using iptables, you can check how many packets got dropped using the blacklist:

```sh
drfalken@wopr:~# iptables -L INPUT -v --line-numbers
Chain INPUT (policy DROP 60 packets, 17733 bytes)
num   pkts bytes target            prot opt in  out source   destination
1       15  1349 DROP              all  --  any any anywhere anywhere     match-set blacklist src
2       10  1029 DROP              all  --  any any anywhere anywhere     match-set countrie src
3        0     0 fail2ban-vsftpd   tcp  --  any any anywhere anywhere     multiport dports ftp,ftp-data,ftps,ftps-data
4      912 69233 fail2ban-ssh-ddos tcp  --  any any anywhere anywhere     multiport dports ssh
5      912 69233 fail2ban-ssh      tcp  --  any any anywhere anywhere     multiport dports ssh
```

Since iptable rules are parsed sequentally, the ipset-blacklist is most effective if it's the **topmost** rule in iptable's INPUT chain. However, restarting fail2ban usually leads to a situation, where fail2ban inserts its rules above our blacklist drop rule. To prevent this from happening we have to tell fail2ban to insert its rules at the 2nd position. Since the iptables-multiport action is the default ban-action we have to add a file to `/etc/fail2ban/action.d`:

```sh
tee << EOF /etc/fail2ban/action.d/iptables-multiport.local
[Definition]
actionstart = <iptables> -N f2b-<name>
              <iptables> -A f2b-<name> -j <returntype>
              <iptables> -I <chain> 2 -p <protocol> -m multiport --dports <port> -j f2b-<name>
EOF
```

(Please keep in in mind this is entirely optional, it just makes dropping blacklisted IP addresses most effective)

## Modify the blacklists you want to use

Edit the BLACKLIST array in /etc/ipset-blacklist/ipset-blacklist.conf to add or remove blacklists, or use it to add your own blacklists.

```sh
BLACKLISTS=(
"http://www.mysite.me/files/mycustomblacklist.txt" # Your personal blacklist
"http://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1"                   # Project Honey Pot Directory of Dictionary Attacker IPs
# I don't want this: "http://www.openbl.org/lists/base.txt"                  # OpenBL.org 30 day List
)
```

If you for some reason want to ban all IP addresses from a certain country, have a look at [IPverse.net's](http://ipverse.net/ipblocks/data/countries/) aggregated IP lists which you can simply add to the BLACKLISTS variable. For a ton of spam and malware related blacklists, check out this github repo: https://github.com/firehol/blocklist-ipsets

## Troubleshooting

### Set blacklist-tmp is full, maxelem 65536 reached

Increase the ipset list capacity. For instance, if you want to store up to 80,000 entries, add these lines to your ipset-blacklist.conf:  

```conf
MAXELEM=80000
```
