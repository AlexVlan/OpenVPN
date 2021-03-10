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

exec bash

