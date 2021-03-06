#!/bin/bash
echo "Этот скрипт создаст OpenVPN сервер с нуля, от вас потребуется указать количество клиентов и минимальные настройки"
echo "К каждому пункту будет пояснение"
echo "Для начала создадим пользователя openvpn"
      #Создадим нового пользователя openvpn с правами администратора
      #Проверка на наличие пользователя в системе, для отсутствия ошибок при повторном запуске
username=openvpn #переменная с именем пользователя
client_name=client #имя клиента
answer=y #ответ пользователя
grep "^$username:" /etc/passwd >/dev/null
if [[ $? -ne 0 ]]; then
   adduser openvpn; usermod -aG wheel openvpn; passwd openvpn
   echo "Пользователь создан"
else
   echo "Пользователь уже создан в системе"
fi
      #Создание клиентов по умолчанию
echo "Укажите количество клиентов по умолчанию. Потом можно добавить еще по необходимости"
read quantity_client
      #Проверка-значение число, иначе сначала
if [[ $quantity_client =~ ^[0-9]+$ ]]; then   #количество клиентов
   echo "Будут создано "$quantity_client" клиентских конфигураций с именами "$client_name"[X].ovpn"
else
   echo "введённый символ не является числом, попробуйте снова"
   echo "Попробовать снова? (y/n/e)"
   read answer
   case $answer in
           "y")
              $0
              ;;
           "n")
              echo "bye"
              exit
              ;;
           "e")
              exit
              ;;
            *)
              echo "error"
              ;;
   esac
fi
echo 'Установим утилиты необходимые для дальнейшей работы'
dnf install wget -y; dnf install tar -y; dnf install zip -y
      #Начинаем установку. Подключим репозиторий и скачаем сам дистрибутив
dnf install epel-release -y; sudo dnf install openvpn -y
      #Проверка наличия директории openvpn если есть то удаляем и создаем заново, иначе создаем
if [[ -e /etc/openvpn ]]; then
   rm -rf /etc/openvpn
   mkdir /etc/openvpn; mkdir /etc/openvpn/keys; chown -R openvpn:openvpn /etc/openvpn
   echo "Удалена старая директория openvpn, создана новая"
else
   mkdir /etc/openvpn; mkdir /etc/openvpn/keys; chown -R openvpn:openvpn /etc/openvpn
   echo "создана новая дирктория openvpn"
fi
      #Скачиваем easy-rsa
wget -P /etc/openvpn https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz
tar -xvzf /etc/openvpn/EasyRSA-3.0.8.tgz -C /etc/openvpn
rm -rf /etc/openvpn/EasyRSA-3.0.8.tgz
      #Создадим файл vars, с настройками пользователя
touch /etc/openvpn/EasyRSA-3.0.8/vars
      #Значения переменных для vars
echo "Укажите основные настройки создания сертификатов"
echo "Для каждого пункта есть настройки по умолчанию, их можно оставить"
echo "Страна(по умолчанию RH):"; read country
if [[ -z $country ]]; then
   country="RH"
fi
echo "Размер ключа(по умолчанию 2048):"; read key_size
if [[ $key_size =~ ^[0-9]+$ ]]; then #проверка на число
   echo "Установлен размер ключа:" $key_size
else
   key_size=2048; echo "Значение ключа установлено по умолчанию"
fi
echo "Укажите область\край(по умолчанию Tegucigalpa"; read province
if [[ -z $province ]]; then
   province="Tegucigalpa"
fi
echo "Город(по умолчанию Tegucigalpa)"; read city
if [[ -z $city ]]; then
   city="Tegucigalpa"
fi
echo "email(по умолчанию temp@mass.hn)"; read mail
if [[ -z $mail ]]; then
   mail="temp@mass.hn"
fi
echo "срок действия сертификата, дней(по умолчанию 3650/10 лет): "; read expire
if [[ $expire =~ ^[0-9]+$ ]]; then
   echo "Срок действия сертификата" $expire "дней"
else
   expire=3650
fi
      #Набиваем vars
cat <<EOF > /etc/openvpn/EasyRSA-3.0.8/vars
set_var EASYRSA_REQ_COUNTRY $country
set_var EASYRSA_KEY_SIZE $key_size
set_var EASYRSA_REQ_PROVINCE $province
set_var EASYRSA_REQ_CITY $city
set_var EASYRSA_REQ_ORG $domain_name
set_var EASYRSA_REQ_EMAIL $mail
set_var EASYRSA_REQ_OU $domain_name
set_var EASYRSA_REQ_CN changeme
set_var EASYRSA_CERT_EXPIRE $expire
set_var EASYRSA_DH_KEY_SIZE $key_size
EOF
      #Теперь инициализируем инфраструктуру публичных ключей
cd /etc/openvpn/; /etc/openvpn/EasyRSA-3.0.8/easyrsa init-pki
      #Создаем свой ключ
/etc/openvpn/EasyRSA-3.0.8/easyrsa build-ca nopass
      #Создаем сертификат сервера
/etc/openvpn/EasyRSA-3.0.8/easyrsa build-server-full server_cert nopass
      #Создаем Диффи Хелмана
/etc/openvpn/EasyRSA-3.0.8/easyrsa gen-dh
      #crl для информации об активных/отозванных сертификатах
/etc/openvpn/EasyRSA-3.0.8/easyrsa gen-crl
      #Теперь копируем все что создали в папку keys
cp /etc/openvpn/pki/ca.crt /etc/openvpn/pki/crl.pem /etc/openvpn/pki/dh.pem /etc/openvpn/keys/
cp /etc/openvpn/pki/issued/server_cert.crt /etc/openvpn/keys/
cp /etc/openvpn/pki/private/server_cert.key /etc/openvpn/keys/

      #Получим настройки для файла server.conf
echo "Сейчас соберем информацию для файла конфигурации сервера."
echo "Порт(по умолчанию 1194):"; read port_num
if [[ $port_num =~ ^[0-9]+$ ]]; then #проверка на число
   echo "Установлен порт:" $port_num
else
   port_num=1194; echo "Номер порта установлен по умолчанию"
echo "Протокол(по умолчанию udp)для установки tcp введите 1"; read protocol
fi
if [[ $protocol -eq 1 ]]; then
   protocol="tcp"
   echo "Выбран протокол tcp"
else
   protocol="udp"
   echo "Выбран протокол udp"
fi
      #Теперь создадим директорию и файлы для логов
mkdir /var/log/openvpn
touch /var/log/openvpn/{openvpn-status,openvpn}.log; chown -R openvpn:openvpn /var/log/openvpn
      #Включаем движение трафика
echo net.ipv4.ip_forward=1 >>/etc/sysctl.conf
sysctl -p /etc/sysctl.conf
      #Настроим selinux
dnf install policycoreutils-python-utils -y
dnf install setroubleshoot -y
semanage port -a -t openvpn_port_t -p $protocol $port_num
/sbin/restorecon -v /var/log/openvpn/openvpn.log
/sbin/restorecon -v /var/log/openvpn/openvpn-status.log
      #Настроим firewalld
firewall-cmd --add-port="$port_num"/"$protocol"
firewall-cmd --zone=trusted --add-source=172.31.1.0/24
firewall-cmd --permanent --add-port="$port_num"/"$protocol"
firewall-cmd --permanent --zone=trusted --add-source=172.31.1.0/24
firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s 172.31.1.0/24 -j MASQUERADE
firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s 172.31.1.0/24 -j MASQUERADE
systemctl restart firewalld
     #Создадим server.conf
mkdir /etc/openvpn/server
touch /etc/openvpn/server/server.conf
#chmod -R a+r /etc/openvpn
cat <<EOF > /etc/openvpn/server/server.conf
port $port_num
proto $protocol
dev tun
ca /etc/openvpn/keys/ca.crt
cert /etc/openvpn/keys/server_cert.crt
key /etc/openvpn/keys/server_cert.key
dh /etc/openvpn/keys/dh.pem
crl-verify /etc/openvpn/keys/crl.pem
topology subnet
server 172.31.1.0 255.255.255.0
route 172.31.1.0 255.255.255.0
push "route 172.31.1.0 255.255.255.0"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 2
mute 20
daemon
mode server
user nobody
group nobody
EOF
echo "Добавим сервер в автозагрузку и запустим"
sudo systemctl enable openvpn-server@server
sudo systemctl start openvpn-server@server
sudo systemctl status openvpn-server@server

      #Начнем создавать клиентов
      #Директория для готовых конфигов
mkdir /home/openvpn/ready_conf
echo "IP к которому необходимо подключаться клиентам в формате 111.111.111.111"; read ip_adress
      #Создадим темповый файл конфигурации клиента с настройками
touch /home/openvpn/temp_conf_client.txt
cat <<EOF > /home/openvpn/temp_conf_client.txt
client
dev tun
proto $protocol
remote $ip_adress $port_num
persist-key
persist-tun
verb 3
route-method exe
route-delay 2
EOF
      #теперь функция создания клиентов
create_client () {
   cd /etc/openvpn/
   /etc/openvpn/EasyRSA-3.0.8/easyrsa build-client-full "$client_name$quantity_client" nopass
   cp /home/openvpn/temp_conf_client.txt /home/openvpn/ready_conf/"$client_name$quantity_client"'.ovpn'
{
   echo "<ca>"; cat "/etc/openvpn/pki/ca.crt"; echo "</ca>"
   echo "<cert>"; awk '/BEGIN/,/END/' "/etc/openvpn/pki/issued/$client_name$quantity_client.crt"; echo "</cert>"
   echo "<key>"; cat "/etc/openvpn/pki/private/$client_name$quantity_client.key"; echo "</key>"
   echo "<dh>"; cat "/etc/openvpn/pki/dh.pem"; echo "</dh>"
} >> "/home/openvpn/ready_conf/"$client_name$quantity_client".ovpn"

} 
      #Запускать функцию создания клиентов, по счетчику
while [[ $quantity_client -ne 0 ]]; do
   create_client
   let "quantity_client=$quantity_client-1"
done
/etc/openvpn/EasyRSA-3.0.8/easyrsa gen-crl #генерируем crl для информации об активных сертификатах
cp /etc/openvpn/pki/crl.pem /etc/openvpn/keys/ #Копируем в директорию с активными сертификатами
sudo systemctl restart openvpn-server@server #перезапускаем сервер, для применения crl
cd /home/openvpn/ready_conf/; ls -alh ./
echo "сейчас вы в директории с готовыми файлами конфигураций, их уже можно использовать"
echo "скрипт завершен успешно"
exec bash

