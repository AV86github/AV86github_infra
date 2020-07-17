# AV86github_infra
AV86github Infra repository

[![Build Status](https://travis-ci.com/Otus-DevOps-2020-02/AV86github_infra.svg?branch=master)](https://travis-ci.com/Otus-DevOps-2020-02/AV86github_infra)

Лекция 5. Домашнее задание
==========================

1. Подключение к внутреннему хосту через *Bastion-host*
    ```
    ssh -i ~/.ssh/gcp_key -A -J gcp@35.210.136.106 gcp@10.132.0.4
    ```
1. Для подключения в одну команду `ssh <host-alias>` создаются *alias* в файле **~/.ssh/config**
    ```
    # defaults value:
    ForwardAgent yes

    # bastion host
    Host bastion
        User gcp
        HostName 35.210.136.106
        IdentityFile ~/.ssh/gcp_key

    # internal host
    Host inthost
        HostName 10.132.0.4
        User gcp
        IdentityFile ~/.ssh/gcp_key
        StrictHostKeyChecking no
        ProxyJump bastion
    ```
1. На хосте **bastion** установлен и настроен VPN сервер.

   Для подключения по vpn через GUI необходимо скачать файл конфигурации пользователя - *cloud-bastion.ovpn* и выполнить команду (запросит логин\пароль)
   ```
   sudo openvpn cloud-bastion.ovpn
   ```
1. pritunl имеет встроенную интеграцию с let's encrypt. Для использования валидного сертификата в настройках Lets Encrypt Domain указать *https://35-228-57-138.sslip.io*. Сертификат сгенерируется сам.
---
Данные для подключения
----------------------
```
bastion_IP = 35.228.57.138
someinternalhost_IP = 10.132.0.4
```

Лекция 6. Домашнее задание
==========================
 В рамках домашнего задания создавался инстанс, правило VPN через утилиту gcloud.
 Доополнительно сделан простейший startup-script (без проверок, только команды).

 1. Создание инстанса со стартап скриптом:

    ```
    startup-script example:
      gcloud compute instances create reddit-app\
      --metadata-from-file startup-script=start-up-script.sh \
      --boot-disk-size=10GB \
      --image-family ubuntu-1604-lts \
      --image-project=ubuntu-os-cloud \
      --machine-type=g1-small \
      --tags puma-server \
      --restart-on-failure
    ```
1. Создание правила VPN:
    ```
    gcloud compute --project=infra-273514 firewall-rules create default-puma-serever --description="enable port 9292 for puma server" --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=tcp:9292 --source-ranges=0.0.0.0/0 --target-tags=puma-server
    ```
---
Параметры для подключения:
```
testapp_IP = 34.107.69.196
testapp_port = 9292
```

Лекция 7. Домашнее задание
==========================

В рамках домашнего задания создавались образы для VM в GCP c помощью утилиты **packer**.

1. Создан базовый образ reddit-base. Перед запуском конфигурационный файл ubuntu16.json провалидирован (в репозиторий закоммичен пример файла с переменными - *variables.json.example*).
    ```
    packer validate -var-file variables.json ./ubuntu16.json
    packer build -var-file variables.json ./ubuntu16.json
    ```

2. Для выполнения домашнего задания со звездочкой, на основе базового образа создан образ reddit-full. Конфигурация описана в файле **immutable.json**
    ```
    packer build -var 'project_id=PR_ID' immutable.json
    ```

3. Для запуска инстанса VM на основе созданного образа можно воспользоваться командой (после запуска сразу же доступен вебсервер):
    ```
    gcloud compute instances create reddit-full \
      --zone=europe-west3-c \
      --machine-type=g1-small \
      --subnet=default \
      --tags=puma-server \
      --image=reddit-full-1593076989 \
      --image-project=infra-273514 \
      --boot-disk-device-name=reddit-full \
      --reservation-affinity=any \
      --restart-on-failure
    ```

Лекция 8. Домашнее задание
==========================

1. В рамках домашнего задания создавалиась инфраструктура в облаке Google с помощью инструмента **terraform**
    Для удобства, различные секции конфигурационного файла разделены на отдельные файлы:
    1. **main.tf** - основной файл с описанием ресурсов и провайдера
    1. **output.tf** - выходные переменные
    1. **variables.tf** - описание input переменных
    1. **terraform.tfvars** - непосредственное определение переменных

1. Выполнено задание со *звездочкой* - добавлен ключ на уровень проекта
    ```
    resource "google_compute_project_metadata" "project_ssh_users" {
    metadata = {
      "ssh-keys"   = "appuser1:${file(var.public_key_path)}"
      }
    }
    ```
    При этом возникает проблема - если добавлять ssh ключи в разных ресурсах, то они перехатирают друг друга.
    Так же можно перетереть ключи, добавленные через web интерфейс.

1. Выполнено задание с двумя звездочками
    - Создан балансировщик http трафика на платформе GCP.
      Основные элементы:
      * Правило переадресации (forward rule)
      * Прокси объект
      * URL Map - сопоставление путей и бэкенд сервисов(используется только один, по умолчанию).
      * Бэкенд сервис (используется health check и группы ВМ для балансировки)
      * Instance Group (Not managed)
   - Адрес балансировщика добалвен в output
   - Добавлен новый инстанс в группу - через объявление нового ресурса в файле main.tf
      При этом приходится вручную копировать код и добавлять инстанс в группу.
   - Кол-во инстансов в группе вынесено в параметр
         ```
         terraform apply -var 'instance_count=2'
         ```

Лекция 9. Домашнее задание
==========================

1. Конфигурация terraform из предыдущего задания была разбита на модули - app, db, vpc.
   В итоге, в основном фале конфигурации остались только раздел с подключением провайдера и модули.

1. Для хранения состояния инфраструктуры в облаке подключен backend на основе **gcs** (с механизмом блокировок)
   При этом:
    * Состояние хранится в облаке, а не локально
    * Нельзя параллельно запускать применение одной конфигурации

1. Доработаны созданные модули - добавлены provisioner для деплоя приложения.

Лекция 10. Домашнее задание
==========================

Практика работы с *Ansible*.

1. При клонировании репозитория, если ansible пишет **Changed=0** значит никаких действий не производилось

1. Написан скрипт **reddit_inventory.py** для генерации инвентори *на лету*
    - Запрашиваетсяя список инстансов в GCE
    - Список фильтруется по тэгам для **app** и **db**
    - Формируется json в формате динамического инвентори
    - выводится stdout через print

Лекция 11. Домашнее задание
==========================

Практика работы с **ansible-playbook**

1. При работе с **GCP** необходимо использовать динамический инвентори. Для этого есть несколько возможностей:
    1. Написать свой скрипт, который возвращает инвентори в формате *json*
    1. Использовать готовый скрипт -  gce.py (поддерживается сообществом, параметризуется через файл gce.ini)
    1. Написать свой плагин
    1. Использовать готовый плагин - gcp_compute (необходимо установить зависимости через pip)

   В этом задании использовался плагин *gcp_compute* с аутентификацией через сервисный аккаунт.

1. Реализованы различные playbook для установки и деплоя приложения:
    * Все таски в одном сценарии одного playbook. Рзаные группы тасков помечены тегами. Запуск:
      ```
      ansible-playbook ... --limit <список хостов> tags <список тэгов>
      ```
    * В рамках одного playbook таски разбиты на сценарии. Сценарии помечены тегами. Запуск:
      ```
      ansible-playbook ... tags <список тэгов>
      ```
    * Сценарии вынесены в отдельные playbook. При запуске нет необходимости указывать **tags, limit**

1. Provisioners для пакера переписаны на ansible playbooks.

Лекция 12. Домашнее задание
==========================

В данном самостоятельном задании было сделано:
1. Практика работы с **ansible role** - созданные ранее плейбуки перенесены в роли

1. Созданы 2 окружения - *stage* и *prod*. Для каждого окружения определены:
    * inventory
    * зашифрованный файл *credentials.yml* с непубличными переменными
    * Зависимости
    * файлы переменных

1. Использована Community роль nginx для доступа к приложению по 80 порту

1. Написан build для Travis CI - проверка синтаксиса файлов по коммиту. Для тестирования использовался:
    ```
    trytravis
    ```

Лекция 13. Домашнее задание
==========================

В домашнем задании практиковались навыки локальной разработки с использованием **Vagrant**.
1. Развернуто локальное окружение на VirtualBox.
    ```
    vagrant up
    ```
1. С использованием Provisioner в *Vagrant* файл приложение reddit задеплоено на виртуальные машины
    ```
    vagrant provisioner dbserver
    ```
1. Таски в ролях **db** и **App** разбиты на функциональные части
1. Для настройки ngnix в локальном окружении в **Vagrant** файл добавлено определение переменной для конфигурации роли ngnix
1. Написаны тесты на **testinfra**
1. Автоматический запуск тестов с использованием фреймворка **molecule**
    ```
    molecule init scenario --scenario-name default -r db -d vagrant
    molecule test # linter
    molecule create # поднимаем локальное окружение
    molecule converge # запуск роли
    molecule verify # запуск тустов
    ```
1. Шаблоны *packer* переделаны на использование ansible ролей
1. Выполнено задание со *****:
    2. Роль DB вынесена в отдельный репозиторий, для которого настраиваем travis\gce\molecule\testinfra\slack
    2. Генерируем ssh ключ для доступа к GCE. Добавляем его в метаданные проекта
    2. через модуль travis шифруем данные для доступа к GCE (**-add** сразу добавляет секрет в .travis.yml, **--com** - НЕ org версия travis):
        ```
        travis encrypt --com GCE_SERVICE_ACCOUNT_EMAIL='Тут почта' --add
        travis encrypt GCE_PROJECT_ID='Тут проект' --add
        ```
    2. Шифруем файл с ключами и сервисным аккаунтом гугл:
        ```
        travis encrypt-file secrets.tar --add
        ```
    2. Инициализируем **molecule** для GCE (сразу создается необходимоя конфигурация):
        ```
        molecule init scenario --scenario-name default -r db -d gce
        ```
    2. Правим конфигурацию **molecule** в файле **molecule.yml**:
        * Меняем зону
        * Меняем image на актуальный
    2. Настраиваем уведомления в slack:
        * Комната в slack уже настроена на получение уведомление из github.
        * Регистрируем оповещение коммитов:
            ```
            /github subscribe AV86github/db_role commits:all
            ```
        * Для настройки уведомлени из travis добавляем в конфигурцию travis блок с нотификациями:
            ```
            notifications:
              slack: Тут нам строчку выдает travis
            ```
