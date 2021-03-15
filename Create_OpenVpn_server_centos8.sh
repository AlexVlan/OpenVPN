#!/bin/bash
echo "Этот скрипт создаст OpenVPN сервер с нуля, от вас потребуется указать колличество клиентов и минимальные настройки"
echo "К каждому пункту будет пояснение"
echo "Для начала создадим пользователя openvpn"
    #Создадим нового пользователя openvpn с правами администратора
    #Проверка на наличие пользователя в системе, для отсутствия ошибок при повторном запуске
username=openvpn #переменная с именем пользователя
#quantity_client  #колличество клиентов
client_name=client
answer=y
grep "^$username:" /etc/passwd >/dev/null
if [[ $? -ne 0 ]]; then
    adduser openvpn; usermod -aG wheel openvpn; passwd openvpn
    echo "Пользователь создан"
else
    echo "Пользователь уже создан в системе"
fi
###Создание клиентов по умолчанию
echo "Укажите колличество клиентов по умолчанию. Потом можно добавить еще по необходимости"
read quantity_client
#Проверка-значение число, иначе сначала
if [[ $quantity_client =~ ^[0-9]+$ ]]; then   #колличество клиентов
   echo "Будут создано "$quantity_client" клиентских конфигураций с именами "$client_name"[X].ovpn"
else
   echo "введеный символ не является числом, попробуйте снова"
   echo "Попробывать снова? (y/n/e)"
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
#Для дальнейших действий авторизуемся под пользователем openvpn
#su openvpn
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
#Значения переменных для vars по дефолту
 echo "Укажите основные настройки создания сертификатов"
 echo "Все значения могут быть от балды, кроме срока действия сертификата"
# echo "Укажите домен:(по умолчанию Hh)"; read domain_name
#if [[ -z $domain_name ]]; then
#        domain_name="Hh"
#fi
 echo "Страна(по умолчанию RH):"; read country
if [[ -z $country ]]; then
        country="RH"
fi
 echo "Размер ключа(по умолчанию 4096):"; read key_size
if [[ $key_size =~ ^[0-9]+$ ]]; then #проверка на число
   echo "Установлен размер ключа:" $key_size
else
   key_size=4096; echo "Значение ключа установлено по умолчанию"
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
#set_var EASYRSA_DN $domain_name
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
#Crl для информации об активных/отозванных сертификатов
/etc/openvpn/EasyRSA-3.0.8/easyrsa gen-crl
#Теперь копируем все что создали в папку keys
cp /etc/openvpn/pki/ca.crt crl.pem dh.pem /etc/openvpn/keys/
cp /etc/openvpn/pki/issued/server_cert.crt /etc/openvpn/keys/
cp /etc/openvpn/keys/private/server_cert.key /etc/openvpn/keys/

#Получим данные для файла server.conf
echo "Сейчас соберем информацию для файла конфигурации сервера."
 echo "Порт(по умолчанию 1194):"; read port_num
if [[ $port_num =~ ^[0-9]+$ ]]; then #проверка на число
   echo "Установлен порт:" $port_num
else
   port_num=1194; echo "Номер порта установлен по умолчанию"
echo "Протокол(по умолчанию udp)для установки tcp введите 1"; read protocol
if [[ $protocol -eq 1 ]]; then
   protocol="tcp"
   echo "Выбран протокол tcp"
else
   protocol="udp"
   echo "Выбран протокол udp"
#Теперь создадим директорию для логов
mkdir /var/log/openvpn
touch /var/log/openvpn/{openvpn-status,openvpn}.log; chown -R openvpn:openvpn /var/log/openvpn

 exec bash














