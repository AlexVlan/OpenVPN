#!/bin/bash
echo "Цей скрипт створить OpenVPN сервер з нуля, від вас буде потрібно вказати кількість клієнтів і мінімальні налаштування"
echo "До кожного пункту буде пояснення"
echo "Для початку створимо користувача openvpn"
      #Створимо нового користувача openvpn з правами адміністратора
      #Перевірка на наявність користувача в системі, для відсутності помилок під час повторного запуску
username=openvpn #змінна з ім'ям користувача
client_name=client #імя кліента
answer=y #відповідь користувача
grep "^$username:" /etc/passwd >/dev/null
if [[ $? -ne 0 ]]; then
   adduser openvpn; usermod -aG wheel openvpn; passwd openvpn
   echo "Користувача створено"
else
   echo "Цей користувач вже існує"
fi
      #Створення користувача за замовчуванням
echo "Вкажіть кількість клієнтів за замовчуванням. Потім можна додати ще за потреби"
read quantity_client
      #Перевірка значення-число, інакше заново
if [[ $quantity_client =~ ^[0-9]+$ ]]; then   #кількість клієнтів
   echo "Буде створено "$quantity_client" клієнтських конфігурацій з іменами "$client_name"[X].ovpn"
else
   echo "введений символ не є числом, спробуйте знову"
   echo "Спробувати знову? (y/n/e)"
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
echo 'Встановимо залежності'
yum install wget -y; yum install tar -y; yum install zip -y; yum install openssl
      #Розпочинаємо встановлення. Підключимо репозиторій та встановимо саму програму
yum install epel-release -y; sudo yum install openvpn -y
      #Перевірка наявності директорії openvpn, якщо є, то видаляємо і створюємо заново, інакше створюємо
if [[ -e /etc/openvpn ]]; then
   rm -rf /etc/openvpn
   mkdir /etc/openvpn; mkdir /etc/openvpn/keys; chown -R openvpn:openvpn /etc/openvpn
   echo "Видалено стару директорію openvpn, створено нову"
else
   mkdir /etc/openvpn; mkdir /etc/openvpn/keys; chown -R openvpn:openvpn /etc/openvpn
   echo "створено нову диркторію openvpn"
fi
      #Завантажуємо easy-rsa
wget -P /etc/openvpn https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz
tar -xvzf /etc/openvpn/EasyRSA-3.0.8.tgz -C /etc/openvpn
rm -rf /etc/openvpn/EasyRSA-3.0.8.tgz
      #Створимо файл vars, з налаштуваннями користувача
touch /etc/openvpn/EasyRSA-3.0.8/vars
      #Значения переменных для vars
echo "Вкажіть основні налаштування створення сертифікатів"
echo "Для кожного пункту є налаштування за замовчуванням, їх можна залишити"
echo "Країна(за замовчуванням RH):"; read country
if [[ -z $country ]]; then
   country="RH"
fi
echo "Розмір ключа(за замовчуванням 2048):"; read key_size
if [[ $key_size =~ ^[0-9]+$ ]]; then #проверка на число
   echo "Встановлено розмір ключа:" $key_size
else
   key_size=2048; echo "Значення ключа встановлено за замовчуванням"
fi
echo "Вкажіть область(за замовчуванням Tegucigalpa"; read province
if [[ -z $province ]]; then
   province="Tegucigalpa"
fi
echo "Місто(за замовчуванням Tegucigalpa)"; read city
if [[ -z $city ]]; then
   city="Tegucigalpa"
fi
echo "email(за замовчуванням temp@mass.hn)"; read mail
if [[ -z $mail ]]; then
   mail="temp@mass.hn"
fi
echo "Строк дії сертифіката, днів(за замовчуванням 3650/10 років): "; read expire
if [[ $expire =~ ^[0-9]+$ ]]; then
   echo "Строк дії сертифіката" $expire "днів"
else
   expire=3650
fi
      #Налаштовуємо vars
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
      #Тепер ініціалізуємо інфраструктуру публічних ключів
cd /etc/openvpn/; /etc/openvpn/EasyRSA-3.0.8/easyrsa init-pki
      #Створюємо свій ключ
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
yum install policycoreutils-python-utils -y
yum install setroubleshoot -y
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
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.4.4"
push  "redirect-gateway def1 bypass-dhcp"
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
