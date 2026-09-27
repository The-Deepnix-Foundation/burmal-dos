#!/usr/bin/env bash
set -uo pipefail
[ -r /etc/profile.d/00locale.sh ] && . /etc/profile.d/00locale.sh
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LANGUAGE=C.UTF-8

TARGET=/mnt/target
LOGFILE=/var/log/burmal-install.log
HAVE_DIALOG=0
command -v dialog >/dev/null 2>&1 && HAVE_DIALOG=1
INSTALL_TTY_STATE=""
INSTALL_INPUT_LOCKED=0
UI_LANG=en
BOOT_MODE=BIOS
PARTITION_MODE=auto
HOME_PART=""
HOME_FORMAT=0
ROOT_PART=""
BOOT_PART=""
NET_MODE=none
WIFI_SSID=""
WIFI_PASS=""

C_GREEN="\033[1;32m"
C_RED="\033[1;31m"
C_YELLOW="\033[1;33m"
C_RESET="\033[0m"

log() { echo "[$(date '+%H:%M:%S')] $*" >>"$LOGFILE"; }
die() { echo -e "${C_RED}Error:${C_RESET} $*" >&2; log "FATAL: $*"; exit 1; }

ui_tr() {
    local text="$1"
    [[ "$UI_LANG" == ru ]] || { printf '%s' "$text"; return; }
    case "$text" in
        "BURMAL-DOS installation") printf 'Установка BURMAL-DOS' ;;
        "Setup is starting. Use the arrow keys and Enter.") printf 'Установка запущена. Используйте стрелки и Enter.' ;;
        "Installer language") printf 'Язык установщика' ;;
        "BURMAL-DOS Installer") printf 'Установщик BURMAL-DOS' ;;
        "Resolving dependencies and calculating the package transaction...") printf 'Проверка зависимостей и подготовка пакетов...' ;;
        "OK") printf 'ОК' ;;
        "Choose the installer language:") printf 'Выберите язык интерфейса установщика:' ;;
        "Choose a city in the selected region:") printf 'Выберите город в выбранном регионе:' ;;
        "Choose a network:") printf 'Выберите сеть:' ;;
        "Cancel") printf 'Отмена' ;;
        "Press Enter to continue...") printf 'Нажмите Enter для продолжения...' ;;
        "Partitioning disk") printf 'Разметка диска' ;;
        "Your choice (number)") printf 'Ваш выбор (номер)' ;;
        "Choose an installation disk:") printf 'Выберите диск для установки:' ;;
        "Disk layout") printf 'Разметка диска' ;;
        "The partition editor will open."*) printf 'Откроется редактор разделов. Сохраните разделы с данными; в свободном месте создайте Linux-раздел для / и, при необходимости, отдельный /home. Не удаляйте существующий EFI-раздел.' ;;
        "Root partition") printf 'Корневой раздел' ;;
        "EFI partition") printf 'EFI-раздел' ;;
        "Home partition") printf 'Раздел /home' ;;
        "Filesystem") printf 'Файловая система' ;;
        "Do not use a separate /home") printf 'Не создавать отдельный /home' ;;
        "No network interfaces were found. Skipping network setup.") printf 'Сетевые интерфейсы не найдены. Настройка сети пропущена.' ;;
        "NetworkManager is unavailable in this live image.") printf 'NetworkManager недоступен в Live-системе.' ;;
        "You must create at least one user account.") printf 'Необходимо создать учётную запись пользователя.' ;;
        "Invalid username. Use lowercase letters, numbers, _ or -; the first character must be a letter or _." ) printf 'Недопустимое имя пользователя. Используйте строчные латинские буквы, цифры, _ или -; первый символ должен быть буквой или _.' ;;
        "No disks were found.") printf 'Диски не найдены.' ;;
        "No disk was selected.") printf 'Диск не выбран.' ;;
        "No partitions were found on "*) printf 'На диске не найдены разделы. Создайте корневой раздел и запустите установщик снова.' ;;
        "cfdisk is missing from the live image.") printf 'В Live-системе отсутствует cfdisk.' ;;
        "No root partition was selected.") printf 'Корневой раздел не выбран.' ;;
        "No existing FAT EFI partition was found. Create one before installing in UEFI mode.") printf 'Не найден EFI-раздел FAT. Создайте его перед установкой в режиме UEFI.' ;;
        "No EFI partition was selected.") printf 'EFI-раздел не выбран.' ;;
        "The EFI and root partitions must be different.") printf 'EFI-раздел и корневой раздел должны быть разными.' ;;
        "The /home partition selection is invalid.") printf 'Выбран недопустимый раздел /home.' ;;
        "Installation cancelled.") printf 'Установка отменена.' ;;
        "Preparing the selected disk partitions. Please wait...") printf 'Подготовка выбранных разделов. Подождите...' ;;
        "Installing system") printf 'Установка системы' ;;
        "Installing the BURMAL-DOS base system. Please wait...") printf 'Установка BURMAL-DOS. Подождите...' ;;
        "Installing BURMAL-DOS packages...") printf 'Установка пакетов BURMAL-DOS...' ;;
        "Configuring system") printf 'Настройка системы' ;;
        "Applying system settings and installing the bootloader. Please wait...") printf 'Применение настроек и установка загрузчика. Подождите...' ;;
        "Configuring BURMAL-DOS and installing the bootloader...") printf 'Настройка BURMAL-DOS и установка загрузчика...' ;;
        "BURMAL-DOS is installed on "*) printf 'BURMAL-DOS установлена. Извлеките носитель установки и перезагрузите компьютер.' ;;
        "Yes") printf 'Да' ;;
        "No") printf 'Нет' ;;
        "Russian") printf 'Русский' ;;
        "English") printf 'Английский' ;;
        "Keyboard layout") printf 'Раскладка клавиатуры' ;;
        "Select a keyboard layout:") printf 'Выберите раскладку клавиатуры:' ;;
        "English (US)") printf 'Английская (США)' ;;
        "Russian (Cyrillic)") printf 'Русская' ;;
        "German") printf 'Немецкая' ;;
        "French (AZERTY)") printf 'Французская (AZERTY)' ;;
        "Spanish") printf 'Испанская' ;;
        "Ukrainian") printf 'Украинская' ;;
        "Computer name") printf 'Имя компьютера' ;;
        "Enter a network name for this computer:") printf 'Введите сетевое имя компьютера:' ;;
        "Invalid name. Use Latin letters, numbers, dots, and hyphens.") printf 'Недопустимое имя. Используйте латинские буквы, цифры, точки и дефисы.' ;;
        "Time zone") printf 'Часовой пояс' ;;
        "Select a region:") printf 'Выберите регион:' ;;
        "Europe") printf 'Европа' ;;
        "Asia") printf 'Азия' ;;
        "America") printf 'Америка' ;;
        "Africa") printf 'Африка' ;;
        "Australia") printf 'Австралия' ;;
        "Coordinated Universal Time") printf 'Всемирное координированное время' ;;
        "Select a city in the selected region:") printf 'Выберите город в выбранном регионе:' ;;
        "System language") printf 'Язык системы' ;;
        "Select the default system locale:") printf 'Выберите локаль системы:' ;;
        "Network") printf 'Сеть' ;;
        "Network setup") printf 'Настройка сети' ;;
        "Choose how to connect to the network:") printf 'Выберите способ подключения к сети:' ;;
        "Wired / automatic") printf 'Проводное подключение / автоматически' ;;
        "Wi-Fi") printf 'Wi-Fi' ;;
        "Continue without network") printf 'Продолжить без сети' ;;
        "No network interfaces were found. Skipping network setup.") printf 'Сетевые интерфейсы не найдены. Настройка сети пропущена.' ;;
        "Select a Wi-Fi network interface:") printf 'Выберите Wi-Fi-адаптер:' ;;
        "Enter the Wi-Fi network name (SSID):") printf 'Введите имя сети Wi-Fi (SSID):' ;;
        "Enter the Wi-Fi password:") printf 'Введите пароль Wi-Fi:' ;;
        "Connecting to Wi-Fi") printf 'Подключение к Wi-Fi' ;;
        "Wi-Fi connection failed. Check the password and try again.") printf 'Не удалось подключиться к Wi-Fi. Проверьте пароль и повторите попытку.' ;;
        "Select a wired network interface:") printf 'Выберите проводной сетевой адаптер:' ;;
        "Unable to activate the network connection.") printf 'Не удалось подключить сеть.' ;;
        "Root password") printf 'Пароль администратора' ;;
        "Enter the administrator password:") printf 'Введите пароль администратора:' ;;
        "Confirm the root password:") printf 'Повторите пароль администратора:' ;;
        "User account") printf 'Учётная запись' ;;
        "Enter a username (with sudo privileges):") printf 'Введите имя пользователя (с правами sudo):' ;;
        "User password") printf 'Пароль пользователя' ;;
        "Enter a password for "*) printf 'Введите пароль для пользователя %s' "${text#Enter a password for }" ;;
        "Confirm the password:") printf 'Повторите пароль:' ;;
        "The passwords do not match or are empty. Try again.") printf 'Пароли не совпадают или пусты. Попробуйте ещё раз.' ;;
        "Error") printf 'Ошибка' ;;
        "Select disk") printf 'Выбор диска' ;;
        "Select installation method:") printf 'Выберите способ разметки:' ;;
        "Use the whole disk (erase all data)") printf 'Весь диск (удалить все данные)' ;;
        "Manual partition selection (keep other partitions)") printf 'Вручную выбрать разделы (сохранить остальные)' ;;
        "Select the root partition (/):") printf 'Выберите корневой раздел (/):' ;;
        "Select the EFI System Partition to use (it will not be formatted):") printf 'Выберите EFI-раздел (он не будет форматироваться):' ;;
        "Select a home partition, or choose none:") printf 'Выберите раздел /home или вариант «не использовать»:' ;;
        "Do you want to format the separate home partition?") printf 'Форматировать отдельный раздел /home?' ;;
        "Select a filesystem for the root partition:") printf 'Выберите файловую систему корневого раздела:' ;;
        "ext4 (recommended)") printf 'ext4 (рекомендуется)' ;;
        "WARNING: the selected partitions will be formatted. Other partitions will be kept.") printf 'ВНИМАНИЕ: выбранные для форматирования разделы будут очищены. Остальные разделы сохранятся.' ;;
        "Scanning for Wi-Fi networks...") printf 'Поиск сетей Wi-Fi...' ;;
        "Please wait while the system is installed.") printf 'Подождите, идёт установка системы.' ;;
        "Confirm installation") printf 'Подтверждение установки' ;;
        "All data on "*) printf 'Данные на выбранных для форматирования разделах будут удалены. Продолжить?' ;;
        "Done") printf 'Готово' ;;
        *) printf '%s' "$text" ;;
    esac
}

ui_msg() {
    if [[ $HAVE_DIALOG -eq 1 ]]; then
        dialog --clear --backtitle "$(ui_tr 'BURMAL-DOS Installer')" --ok-label "$(ui_tr 'OK')" --cancel-label "$(ui_tr 'Cancel')" --title "$1" --msgbox "$2" 12 60
    else
        printf '\n== %s ==\n%s\n' "$1" "$2" > /dev/tty
        read -rp "$(ui_tr 'Press Enter to continue...')" _ < /dev/tty
    fi
}
ui_status() {
    if [[ $HAVE_DIALOG -eq 1 ]]; then
        dialog --clear --backtitle "$(ui_tr 'BURMAL-DOS Installer')" --title "$1" --infobox "$2" 8 68
    else
        printf '\n== %s ==\n%s\n' "$1" "$2" > /dev/tty
    fi
}
show_progress() {
    local message="$1" percent="$2" filled i
    (( percent < 0 )) && percent=0
    (( percent > 100 )) && percent=100
    if [[ $HAVE_DIALOG -eq 1 ]]; then
        printf 'XXX\n%s\nXXX\n%d\n' "$message" "$percent"
        return
    fi

    filled=$((percent * 24 / 100))
    printf '\r%s [' "$message" > /dev/tty
    for ((i = 0; i < 24; i++)); do
        if (( i < filled )); then printf '#' > /dev/tty; else printf ' ' > /dev/tty; fi
    done
    printf '] %3d%%' "$percent" > /dev/tty
}
run_with_progress() {
    local title="$1" message="$2" progress_file="$3" result=0 percent=0
    shift 3
    lock_installer_input

    if [[ $HAVE_DIALOG -eq 1 ]]; then
        (
            "$@" >>"$LOGFILE" 2>&1 &
            local command_pid=$!
            while kill -0 "$command_pid" 2>/dev/null; do
                if [[ -r "$progress_file" ]]; then
                    local reported
                    reported=$(<"$progress_file")
                    [[ "$reported" =~ ^[0-9]+$ ]] && (( reported > percent )) && percent=$reported
                fi
                show_progress "$message" "$percent"
                sleep 0.2
            done
            wait "$command_pid" || exit $?
            show_progress "$message" 100
        ) | dialog --clear --backtitle "$(ui_tr 'BURMAL-DOS Installer')" --title "$title" --gauge "$message" 8 68 0
        result=${PIPESTATUS[0]}
    else
        "$@" >>"$LOGFILE" 2>&1 &
        local command_pid=$!
        while kill -0 "$command_pid" 2>/dev/null; do
            if [[ -r "$progress_file" ]]; then
                local reported
                reported=$(<"$progress_file")
                [[ "$reported" =~ ^[0-9]+$ ]] && (( reported > percent )) && percent=$reported
            fi
            show_progress "$message" "$percent"
            sleep 0.2
        done
        wait "$command_pid" || result=$?
        [[ $result -eq 0 ]] && percent=100
        show_progress "$message" "$percent"
        printf '\n' > /dev/tty
    fi

    return "$result"
}

run_xbps_install_progress() {
    local repository="$1" target="$2" title="$3" message="$4"
    shift 4
    local -a packages=("$@")
    local plan_file trace_file planned=0 command="" result=0 percent=0 download_percent="" installed=0

    ui_status "$title" "$(ui_tr 'Resolving dependencies and calculating the package transaction...')"
    plan_file=$(mktemp /tmp/burmal-xbps-plan.XXXXXX)
    trace_file=$(mktemp /tmp/burmal-xbps-progress.XXXXXX)
    if ! env XBPS_ARCH=x86_64 xbps-install -S -M -n -R "$repository" -r "$target" \
        "${packages[@]}" >"$plan_file" 2>>"$LOGFILE"; then
        cat "$plan_file" >>"$LOGFILE"
        rm -f "$plan_file" "$trace_file"
        return 1
    fi
    planned=$(awk '$2 == "install" || $2 == "reinstall" || $2 == "update" { n++ } END { print n+0 }' "$plan_file")
    rm -f "$plan_file"

    printf -v command '%q ' env XBPS_ARCH=x86_64 xbps-install -S -y -R "$repository" -r "$target" "${packages[@]}"
    lock_installer_input
    if [[ $HAVE_DIALOG -eq 1 ]]; then
        (
            script -qefc "$command" "$trace_file" >/dev/null 2>&1 &
            local command_pid=$!
            while kill -0 "$command_pid" 2>/dev/null; do
                download_percent=$(tr '\r' '\n' < "$trace_file" | sed -nE 's/^\[[[:space:]]*([0-9]{1,3})%\].*/\1/p' | tail -n 1)
                installed=$(tr '\r' '\n' < "$trace_file" | awk '/: (installed|updated) successfully\./ { n++ } END { print n+0 }')
                if [[ -n "$download_percent" ]]; then
                    percent=$((download_percent * 60 / 100))
                fi
                if grep -Fq '[*] Unpacking packages' "$trace_file" 2>/dev/null; then
                    if (( planned > 0 )); then percent=$((60 + installed * 39 / planned)); else percent=99; fi
                    (( percent > 99 )) && percent=99
                fi
                show_progress "$message" "$percent"
                sleep 0.25
            done
            wait "$command_pid" || exit $?
            show_progress "$message" 100
        ) | dialog --clear --backtitle "$(ui_tr 'BURMAL-DOS Installer')" --title "$title" --gauge "$message" 8 68 0
        result=${PIPESTATUS[0]}
    else
        script -qefc "$command" "$trace_file" >/dev/null 2>&1 &
        local command_pid=$!
        while kill -0 "$command_pid" 2>/dev/null; do
            download_percent=$(tr '\r' '\n' < "$trace_file" | sed -nE 's/^\[[[:space:]]*([0-9]{1,3})%\].*/\1/p' | tail -n 1)
            installed=$(tr '\r' '\n' < "$trace_file" | awk '/: (installed|updated) successfully\./ { n++ } END { print n+0 }')
            if [[ -n "$download_percent" ]]; then percent=$((download_percent * 60 / 100)); fi
            if grep -Fq '[*] Unpacking packages' "$trace_file" 2>/dev/null; then
                if (( planned > 0 )); then percent=$((60 + installed * 39 / planned)); else percent=99; fi
                (( percent > 99 )) && percent=99
            fi
            show_progress "$message" "$percent"
            sleep 0.25
        done
        wait "$command_pid" || result=$?
        [[ $result -eq 0 ]] && percent=100
        show_progress "$message" "$percent"
        printf '\n' > /dev/tty
    fi

    tr '\r' '\n' < "$trace_file" >>"$LOGFILE"
    rm -f "$trace_file"
    return "$result"
}

lock_installer_input() {
    [[ $INSTALL_INPUT_LOCKED -eq 1 ]] && return 0
    [[ -r /dev/tty ]] || return 0
    INSTALL_TTY_STATE=$(stty -g < /dev/tty 2>/dev/null) || return 0
    stty -echo -icanon < /dev/tty 2>/dev/null || return 0
    INSTALL_INPUT_LOCKED=1
    trap restore_installer_input EXIT
}

restore_installer_input() {
    [[ $INSTALL_INPUT_LOCKED -eq 1 ]] || return 0
    while IFS= read -r -t 0.05 -n 1 _installer_key < /dev/tty; do :; done 2>/dev/null || true
    stty "$INSTALL_TTY_STATE" < /dev/tty 2>/dev/null || true
    INSTALL_INPUT_LOCKED=0
}

ui_input() {
    local title="$1" prompt="$2" default="${3:-}"
    local result
    if [[ $HAVE_DIALOG -eq 1 ]]; then
        result=$(dialog --clear --backtitle "$(ui_tr 'BURMAL-DOS Installer')" --ok-label "$(ui_tr 'OK')" --cancel-label "$(ui_tr 'Cancel')" --title "$title" \
            --inputbox "$prompt" 10 60 "$default" 3>&1 1>&2 2>&3)
    else
        printf '\n== %s ==\n' "$title" > /dev/tty
        read -rp "$prompt [$default]: " result < /dev/tty
        result="${result:-$default}"
    fi
    printf '%s\n' "$result"
}

ui_password() {
    local title="$1" prompt="$2"
    local result
    if [[ $HAVE_DIALOG -eq 1 ]]; then
        result=$(dialog --clear --backtitle "$(ui_tr 'BURMAL-DOS Installer')" --ok-label "$(ui_tr 'OK')" --cancel-label "$(ui_tr 'Cancel')" --title "$title" \
            --insecure --passwordbox "$prompt" 10 60 3>&1 1>&2 2>&3)
    else
        read -rsp "$prompt: " result < /dev/tty; echo > /dev/tty
    fi
    printf '%s\n' "$result"
}

ui_menu() {
    local title="$1" prompt="$2"; shift 2
    local items=("$@")
    local result
    if [[ $HAVE_DIALOG -eq 1 ]]; then
        result=$(dialog --clear --backtitle "$(ui_tr 'BURMAL-DOS Installer')" --ok-label "$(ui_tr 'OK')" --cancel-label "$(ui_tr 'Cancel')" --title "$title" \
            --menu "$prompt" 22 68 14 "${items[@]}" 3>&1 1>&2 2>&3)
    else
        printf '\n== %s ==\n%s\n' "$title" "$prompt" > /dev/tty
        local i=1 tags=()
        while [[ $i -le ${#items[@]} ]]; do
            local tag="${items[$((i-1))]}" desc="${items[$i]}"
        printf '  %d. %s  (%s)\n' "$((i/2+1))" "$desc" "$tag" > /dev/tty
            tags+=("$tag")
            i=$((i+2))
        done
        local choice
        read -rp "$(ui_tr 'Your choice (number)'): " choice < /dev/tty
        result="${tags[$((choice-1))]}"
    fi
    echo "$result"
}

ui_yesno() {
    local title="$1" prompt="$2"
    if [[ $HAVE_DIALOG -eq 1 ]]; then
        dialog --clear --backtitle "$(ui_tr 'BURMAL-DOS Installer')" --yes-label "$(ui_tr 'Yes')" --no-label "$(ui_tr 'No')" --title "$title" --yesno "$prompt" 10 60
        return $?
    else
        read -rp "$prompt [y/N]: " ans
        [[ "$ans" =~ ^([Yy]|1)$ ]]
        return $?
    fi
}

ui_checklist() {
    local title="$1" prompt="$2"; shift 2
    if [[ $HAVE_DIALOG -eq 1 ]]; then
        dialog --clear --backtitle "$(ui_tr 'BURMAL-DOS Installer')" --ok-label "$(ui_tr 'OK')" --cancel-label "$(ui_tr 'Cancel')" --title "$title" \
            --checklist "$prompt" 22 68 14 "$@" 3>&1 1>&2 2>&3
    else
        echo "(Text mode: this option is unavailable and will be skipped.)"
    fi
}

show_welcome() {
    clear
    printf '%b\n' "${C_GREEN}$(ui_tr 'BURMAL-DOS installation')${C_RESET}"
    echo "$(ui_tr 'Setup is starting. Use the arrow keys and Enter.')"
}

step_language() {
    UI_LANG=$(ui_menu "Язык / Language" "Выберите язык / Choose the installer language:" \
        ru "Русский" \
        en "English")
    [[ "$UI_LANG" == ru ]] || UI_LANG=en
    if [[ "$UI_LANG" == ru ]] && locale -a 2>/dev/null | grep -qi '^ru_RU\.utf8$'; then
        export LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 LANGUAGE=ru_RU:ru
    elif locale -a 2>/dev/null | grep -qi '^en_US\.utf8$'; then
        export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US:en
    else
        export LANG=C.UTF-8 LC_ALL=C.UTF-8 LANGUAGE=C.UTF-8
    fi
}
step_keyboard() {
    KEYMAP=$(ui_menu "$(ui_tr 'Keyboard layout')" "$(ui_tr 'Select a keyboard layout:')" \
        us "$(ui_tr 'English (US)')" \
        ru "$(ui_tr 'Russian (Cyrillic)')" \
        de "$(ui_tr 'German')" \
        fr "$(ui_tr 'French (AZERTY)')" \
        ua "$(ui_tr 'Ukrainian')")
    KEYMAP="${KEYMAP:-us}"
    [[ "$KEYMAP" == ru ]] && KEYMAP=ruwin_alt_sh-UTF-8
    loadkeys "$KEYMAP" 2>/dev/null || true
    log "keymap=$KEYMAP"
}

step_hostname() {
    HOSTNAME=$(ui_input "$(ui_tr 'Computer name')" "$(ui_tr 'Enter a network name for this computer:')" "burmal-dos")
    [[ -z "$HOSTNAME" ]] && HOSTNAME="burmal-dos"
    [[ "$HOSTNAME" =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,62}$ ]] || die "$(ui_tr 'Invalid name. Use Latin letters, numbers, dots, and hyphens.')"
    log "hostname=$HOSTNAME"
}


step_timezone() {
    REGION=$(ui_menu "$(ui_tr 'Time zone')" "$(ui_tr 'Select a region:')" \
        Europe "$(ui_tr 'Europe')" \
        Asia "$(ui_tr 'Asia')" \
        America "$(ui_tr 'America')" \
        Africa "$(ui_tr 'Africa')" \
        Australia "$(ui_tr 'Australia')" \
        UTC "$(ui_tr 'Coordinated Universal Time')")
    if [[ "$REGION" == "UTC" ]]; then
        TIMEZONE="UTC"
    else
        local cities
        cities=$(ls "/usr/share/zoneinfo/$REGION" 2>/dev/null | head -n 40)
        if [[ -z "$cities" ]]; then
            TIMEZONE="UTC"
        else
            local menu_items=()
            for c in $cities; do menu_items+=("$c" "$c"); done
            CITY=$(ui_menu "$(ui_tr 'Time zone')" "$(ui_tr 'Select a city in the selected region:')" "${menu_items[@]}")
            TIMEZONE="$REGION/${CITY:-UTC}"
        fi
    fi
    log "timezone=$TIMEZONE"
}


step_locale() {
    local default_locale=en_US.UTF-8
    local -a locale_items
    [[ "$UI_LANG" == ru ]] && default_locale=ru_RU.UTF-8
    if [[ "$UI_LANG" == ru ]]; then
        locale_items=(ru_RU.UTF-8 "$(ui_tr 'Russian')" en_US.UTF-8 "$(ui_tr 'English (US)')" \
            de_DE.UTF-8 "$(ui_tr 'German')" fr_FR.UTF-8 "$(ui_tr 'French (AZERTY)')" es_ES.UTF-8 "$(ui_tr 'Spanish')")
    else
        locale_items=(en_US.UTF-8 "$(ui_tr 'English (US)')" ru_RU.UTF-8 "$(ui_tr 'Russian')" \
            de_DE.UTF-8 "$(ui_tr 'German')" fr_FR.UTF-8 "$(ui_tr 'French (AZERTY)')" es_ES.UTF-8 "$(ui_tr 'Spanish')")
    fi
    LOCALE=$(ui_menu "$(ui_tr 'System language')" "$(ui_tr 'Select the default system locale:')" "${locale_items[@]}")
    LOCALE="${LOCALE:-$default_locale}"
    log "locale=$LOCALE"
}

step_network() {
    local wifi_devs wired_devs menu_items=() iface ssid_list
    command -v nmcli >/dev/null 2>&1 || {
        ui_msg "$(ui_tr 'Network')" "$(ui_tr 'NetworkManager is unavailable in this live image.')"
        return
    }
    nmcli radio wifi on >/dev/null 2>&1 || true
    wifi_devs=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1}')
    wired_devs=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="ethernet"{print $1}')
    [[ -n "$wired_devs" ]] && menu_items+=(wired "$(ui_tr 'Wired / automatic')")
    [[ -n "$wifi_devs" ]] && menu_items+=(wifi "$(ui_tr 'Wi-Fi')")
    menu_items+=(skip "$(ui_tr 'Continue without network')")
    NET_MODE=$(ui_menu "$(ui_tr 'Network setup')" "$(ui_tr 'Choose how to connect to the network:')" "${menu_items[@]}")
    case "$NET_MODE" in
        wired)
            menu_items=()
            for iface in $wired_devs; do menu_items+=("$iface" "$iface"); done
            NET_IFACE=$(ui_menu "$(ui_tr 'Network')" "$(ui_tr 'Select a wired network interface:')" "${menu_items[@]}")
            nmcli device connect "$NET_IFACE" >/dev/null 2>&1 || {
                ui_msg "$(ui_tr 'Network')" "$(ui_tr 'Unable to activate the network connection.')"
            }
            ;;
        wifi)
            menu_items=()
            for iface in $wifi_devs; do menu_items+=("$iface" "$iface"); done
            NET_IFACE=$(ui_menu "$(ui_tr 'Network')" "$(ui_tr 'Select a Wi-Fi network interface:')" "${menu_items[@]}")
            ui_status "$(ui_tr 'Wi-Fi')" "$(ui_tr 'Scanning for Wi-Fi networks...')"
            nmcli device wifi rescan ifname "$NET_IFACE" >/dev/null 2>&1 || true
            sleep 2
            ssid_list=$(nmcli --escape no -t -f SSID device wifi list ifname "$NET_IFACE" 2>/dev/null | sed '/^[[:space:]]*$/d' | sort -u | head -n 30)
            menu_items=()
            while IFS= read -r iface; do [[ -n "$iface" ]] && menu_items+=("$iface" ""); done <<< "$ssid_list"
            if ((${#menu_items[@]})); then
                WIFI_SSID=$(ui_menu "$(ui_tr 'Wi-Fi')" "$(ui_tr 'Choose a network:')" "${menu_items[@]}")
            else
                WIFI_SSID=$(ui_input "$(ui_tr 'Wi-Fi')" "$(ui_tr 'Enter the Wi-Fi network name (SSID):')" "")
            fi
            WIFI_PASS=$(ui_password "$(ui_tr 'Wi-Fi')" "$(ui_tr 'Enter the Wi-Fi password:')")
            if [[ -n "$WIFI_PASS" ]]; then
                nmcli --wait 40 device wifi connect "$WIFI_SSID" password "$WIFI_PASS" ifname "$NET_IFACE" >>"$LOGFILE" 2>&1
            else
                nmcli --wait 40 device wifi connect "$WIFI_SSID" ifname "$NET_IFACE" >>"$LOGFILE" 2>&1
            fi
            if [[ $? -ne 0 ]]; then
                ui_msg "$(ui_tr 'Network')" "$(ui_tr 'Wi-Fi connection failed. Check the password and try again.')"
                WIFI_SSID=""
                WIFI_PASS=""
            fi
            ;;
        *) NET_MODE=none ;;
    esac
    log "net_mode=$NET_MODE iface=${NET_IFACE:-} wifi_connected=$([[ -n "$WIFI_SSID" ]] && echo yes || echo no)"
}


step_users() {
    while true; do
        ROOT_PASS1=$(ui_password "$(ui_tr 'Root password')" "$(ui_tr 'Enter the administrator password:')")
        ROOT_PASS2=$(ui_password "$(ui_tr 'Root password')" "$(ui_tr 'Confirm the root password:')")
        [[ "$ROOT_PASS1" == "$ROOT_PASS2" && -n "$ROOT_PASS1" ]] && break
        ui_msg "$(ui_tr 'Error')" "$(ui_tr 'The passwords do not match or are empty. Try again.')"
    done

    USERNAME=$(ui_input "$(ui_tr 'User account')" "$(ui_tr 'Enter a username (with sudo privileges):')" "user")
    [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "$(ui_tr 'Invalid username. Use lowercase letters, numbers, _ or -; the first character must be a letter or _.')"
    while true; do
        USER_PASS1=$(ui_password "$(ui_tr 'User password')" "$(ui_tr "Enter a password for $USERNAME:")")
        USER_PASS2=$(ui_password "$(ui_tr 'User password')" "$(ui_tr 'Confirm the password:')")
        [[ "$USER_PASS1" == "$USER_PASS2" && -n "$USER_PASS1" ]] && break
        ui_msg "$(ui_tr 'Error')" "$(ui_tr 'The passwords do not match or are empty. Try again.')"
    done
    log "username=$USERNAME"
}

step_disk() {
    local disks mode partitions p_name p_size p_type p_fstype menu_items=() esp_items=() home_items=()
    if [[ -d /sys/firmware/efi ]]; then BOOT_MODE=UEFI; else BOOT_MODE=BIOS; fi
    disks=$(lsblk -dno NAME,SIZE,TYPE 2>/dev/null | awk '$3=="disk"{print $1" "$2}')
    [[ -z "$disks" ]] && die "No disks were found."

    local menu_items=()
    while read -r name size; do
        menu_items+=("/dev/$name" "$size")
    done <<<"$disks"

    DISK=$(ui_menu "$(ui_tr 'Select disk')" "$(ui_tr 'Choose an installation disk:')" "${menu_items[@]}")
    [[ -z "$DISK" ]] && die "No disk was selected."

    mode=$(ui_menu "$(ui_tr 'Disk layout')" "$(ui_tr 'Select installation method:')" \
        auto "$(ui_tr 'Use the whole disk (erase all data)')" \
        manual "$(ui_tr 'Manual partition selection (keep other partitions)')")
    PARTITION_MODE="${mode:-auto}"
    if [[ "$PARTITION_MODE" == manual ]]; then
        ui_msg "$(ui_tr 'Disk layout')" "$(ui_tr 'The partition editor will open. Keep existing data partitions; create an empty Linux root partition and optional home partition in free space. Do not delete the existing EFI partition.')"
        command -v cfdisk >/dev/null 2>&1 || die "cfdisk is missing from the live image."
        cfdisk "$DISK" > /dev/tty 2>&1
        partprobe "$DISK" 2>/dev/null || true
        command -v udevadm >/dev/null 2>&1 && udevadm settle --timeout=5 2>/dev/null || true
        partitions=$(lsblk -rpn -o NAME,SIZE,TYPE,FSTYPE "$DISK" | awk '$3=="part"')
        [[ -n "$partitions" ]] || die "No partitions were found on $DISK. Create a root partition and restart the installer."
        menu_items=()
        while read -r p_name p_size p_type p_fstype; do
            menu_items+=("$p_name" "${p_size} ${p_fstype:-unknown}")
        done <<< "$partitions"
        ROOT_PART=$(ui_menu "$(ui_tr 'Root partition')" "$(ui_tr 'Select the root partition (/):')" "${menu_items[@]}")
        [[ -b "$ROOT_PART" ]] || die "No root partition was selected."
        if [[ "$BOOT_MODE" == UEFI ]]; then
            esp_items=()
            while read -r p_name p_size p_type p_fstype; do
                [[ "$p_fstype" == vfat || "$p_fstype" == fat || "$p_fstype" == FAT32 ]] && esp_items+=("$p_name" "$p_size")
            done <<< "$partitions"
            ((${#esp_items[@]})) || die "No existing FAT EFI partition was found. Create one before installing in UEFI mode."
            BOOT_PART=$(ui_menu "$(ui_tr 'EFI partition')" "$(ui_tr 'Select the EFI System Partition to use (it will not be formatted):')" "${esp_items[@]}")
            [[ -b "$BOOT_PART" ]] || die "No EFI partition was selected."
            [[ "$BOOT_PART" != "$ROOT_PART" ]] || die "The EFI and root partitions must be different."
        fi

        home_items=(none "$(ui_tr 'Do not use a separate /home')")
        while read -r p_name p_size p_type p_fstype; do
            [[ "$p_name" != "$ROOT_PART" && "$p_name" != "$BOOT_PART" ]] && home_items+=("$p_name" "${p_size} ${p_fstype:-unknown}")
        done <<< "$partitions"
        HOME_PART=$(ui_menu "$(ui_tr 'Home partition')" "$(ui_tr 'Select a home partition, or choose none:')" "${home_items[@]}")
        if [[ "$HOME_PART" == none ]]; then HOME_PART=""; else
            [[ -b "$HOME_PART" ]] || die "The /home partition selection is invalid."
            if ui_yesno "$(ui_tr 'Home partition')" "$(ui_tr 'Do you want to format the separate home partition?')"; then HOME_FORMAT=1; fi
        fi
        FS_TYPE=$(ui_menu "$(ui_tr 'Filesystem')" "$(ui_tr 'Select a filesystem for the root partition:')" \
            ext4 "$(ui_tr 'ext4 (recommended)')" btrfs "btrfs" xfs "xfs")
        [[ -n "$FS_TYPE" ]] || FS_TYPE=ext4
        confirm_prompt='WARNING: the selected partitions will be formatted. Other partitions will be kept.'
        [[ "$UI_LANG" == ru ]] && confirm_prompt='ВНИМАНИЕ: выбранные для форматирования разделы будут очищены. Остальные разделы сохранятся.'
        ui_yesno "$(ui_tr 'Confirm installation')" "$(ui_tr "$confirm_prompt")"
        [[ $? -eq 0 ]] || die "Installation cancelled."
    else
        ROOT_PART=""
        BOOT_PART=""
        HOME_PART=""
        FS_TYPE=$(ui_menu "$(ui_tr 'Filesystem')" "$(ui_tr 'Select a filesystem for the root partition:')" \
            ext4 "$(ui_tr 'ext4 (recommended)')" btrfs "btrfs" xfs "xfs")
        [[ -n "$FS_TYPE" ]] || FS_TYPE=ext4
        confirm_prompt="All data on $DISK will be erased. Continue?"
        [[ "$UI_LANG" == ru ]] && confirm_prompt="Весь диск $DISK будет очищен. Продолжить?"
        ui_yesno "$(ui_tr 'Confirm installation')" "$confirm_prompt"
        [[ $? -eq 0 ]] || die "Installation cancelled."
    fi
    log "disk=$DISK fs=$FS_TYPE partition_mode=$PARTITION_MODE boot_mode=$BOOT_MODE root=$ROOT_PART efi=$BOOT_PART home=$HOME_PART"
}

do_partition() {
    lock_installer_input
    ui_status "$(ui_tr 'Partitioning disk')" "$(ui_tr 'Preparing the selected disk partitions. Please wait...')"
    log "partitioning $DISK mode=$PARTITION_MODE boot=$BOOT_MODE"

    if [[ "$PARTITION_MODE" == manual ]]; then
        case "$FS_TYPE" in
            ext4)  mkfs.ext4 -F "$ROOT_PART" ;;
            btrfs) mkfs.btrfs -f "$ROOT_PART" ;;
            xfs)   mkfs.xfs -f "$ROOT_PART" ;;
        esac || die "Failed to format the root partition $ROOT_PART."
        if [[ -n "$HOME_PART" && "$HOME_FORMAT" -eq 1 ]]; then
            mkfs.ext4 -F "$HOME_PART" || die "Failed to format the /home partition $HOME_PART."
        fi
        mkdir -p "$TARGET"
        mount "$ROOT_PART" "$TARGET" || die "Failed to mount the root filesystem."
        if [[ "$BOOT_MODE" == UEFI ]]; then
            mkdir -p "$TARGET/boot/efi"
            mount "$BOOT_PART" "$TARGET/boot/efi" || die "Failed to mount the EFI partition."
        fi
        if [[ -n "$HOME_PART" ]]; then
            mkdir -p "$TARGET/home"
            mount "$HOME_PART" "$TARGET/home" || die "Failed to mount the /home partition."
        fi
        return
    fi

    swapoff -a 2>/dev/null || true
    umount -R "$TARGET" 2>/dev/null || true
    for part in "$DISK"*; do
        [ -e "$part" ] && [ "$part" != "$DISK" ] && umount -f "$part" 2>/dev/null
    done
    command -v vgchange >/dev/null 2>&1 && vgchange -an 2>/dev/null
    command -v wipefs   >/dev/null 2>&1 && wipefs -a "$DISK" 2>/dev/null
    partprobe "$DISK" 2>/dev/null
    blockdev --rereadpt "$DISK" 2>/dev/null
    sleep 1

    if [[ "$BOOT_MODE" == UEFI ]]; then
        parted -s "$DISK" mklabel gpt \
            mkpart ESP fat32 1MiB 513MiB \
            set 1 esp on \
            mkpart primary 513MiB 100% \
            || die "Failed to partition $DISK with parted.

If the error \"Partition(s) ... are being used\" persists:
1) Make sure $DISK is a separate empty disk, not the device used to boot
   this live image (attach the ISO as a CD/DVD device);
2) reboot the virtual machine or computer and restart the installer."
        if [[ "$DISK" =~ [0-9]$ ]]; then part_sep=p; else part_sep=""; fi
        BOOT_PART="${DISK}${part_sep}1"
        ROOT_PART="${DISK}${part_sep}2"
    else
        parted -s "$DISK" mklabel gpt \
            mkpart primary 1MiB 2MiB \
            set 1 bios_grub on \
            mkpart primary 2MiB 100% \
            || die "Failed to partition $DISK for legacy BIOS boot."
        BOOT_PART=""
        if [[ "$DISK" =~ [0-9]$ ]]; then part_sep=p; else part_sep=""; fi
        ROOT_PART="${DISK}${part_sep}2"
    fi

    partprobe "$DISK" 2>/dev/null || true
    sleep 1

    command -v udevadm >/dev/null 2>&1 && udevadm settle --timeout=5 2>/dev/null
    for _i in 1 2 3 4 5; do
        if [[ "$BOOT_MODE" == UEFI ]]; then
            [ -b "$BOOT_PART" ] && [ -b "$ROOT_PART" ] && break
        else
            [ -b "$ROOT_PART" ] && break
        fi
        partprobe "$DISK" 2>/dev/null
        sleep 1
    done
    [ -b "$ROOT_PART" ] || die "Partition $ROOT_PART was not created on $DISK."
    if [[ "$BOOT_MODE" == UEFI ]]; then
        [ -b "$BOOT_PART" ] || die "EFI partition $BOOT_PART was not created on $DISK."
        mkfs.vfat -F32 "$BOOT_PART" || die "Failed to create the EFI partition."
    fi
    case "$FS_TYPE" in
        ext4)  mkfs.ext4 -F "$ROOT_PART" ;;
        btrfs) mkfs.btrfs -f "$ROOT_PART" ;;
        xfs)   mkfs.xfs -f "$ROOT_PART" ;;
    esac || die "Failed to create the root filesystem."

    mkdir -p "$TARGET"
    mount "$ROOT_PART" "$TARGET" || die "Failed to mount the root filesystem."
    if [[ "$BOOT_MODE" == UEFI ]]; then
        mkdir -p "$TARGET/boot/efi"
        mount "$BOOT_PART" "$TARGET/boot/efi" || die "Failed to mount the EFI partition."
    fi
}
do_install_base() {
    ui_status "$(ui_tr 'Installing system')" "$(ui_tr 'Installing the BURMAL-DOS base system. Please wait...')"
    log "installing BURMAL-DOS base system into $TARGET"
    mkdir -p "$TARGET"

    BURMAL_REPOSITORY="https://repo-default.voidlinux.org/current"
    if [ -r /etc/burmal-repository ]; then
        . /etc/burmal-repository
        BURMAL_REPOSITORY="${BURMAL_REPOSITORY:-$BURMAL_REPOSITORY}"
    fi
    mkdir -p "$TARGET/var/db/xbps/keys" "$TARGET/etc/xbps.d"
    cp -a /var/db/xbps/keys/. "$TARGET/var/db/xbps/keys/" 2>/dev/null ||
        die "BURMAL-DOS repository signing keys are missing from the live system."
    printf 'repository=%s\n' "$BURMAL_REPOSITORY" > "$TARGET/etc/xbps.d/00-repository-main.conf"
    for fs in dev proc sys; do
        mkdir -p "$TARGET/$fs"
        mount --rbind "/$fs" "$TARGET/$fs" || die "Failed to bind-mount /$fs into the target."
        mount --make-rslave "$TARGET/$fs" 2>/dev/null || true
    done

    run_xbps_install_progress "$BURMAL_REPOSITORY" "$TARGET" "$(ui_tr 'Installing system')" "$(ui_tr 'Installing BURMAL-DOS packages...')" \
        base-system linux linux-firmware dialog parted e2fsprogs dosfstools btrfs-progs xfsprogs \
        grub grub-i386-efi grub-x86_64-efi efibootmgr sudo shadow kbd util-linux xbps \
        terminus-font glibc-locales tzdata dracut NetworkManager dbus wpa_supplicant \
        xorg-minimal xorg-server xinit xauth xrandr spice-vdagent \
        xf86-input-libinput xf86-video-vesa eudev mesa-dri python3 python3-tkinter dejavu-fonts-ttf
    [ $? -eq 0 ] || die "Failed to install BURMAL-DOS base packages. See $LOGFILE for details."
    mkdir -p "$TARGET/usr/share/burmal-dos" "$TARGET/usr/share/backgrounds" "$TARGET/etc/fastfetch" "$TARGET/etc/dpx"
    cp -f /usr/share/burmal-dos/branding/os-release "$TARGET/usr/lib/os-release"
    cp -f /usr/share/burmal-dos/branding/issue "$TARGET/etc/issue"
    cp -f /usr/share/burmal-dos/branding/motd "$TARGET/etc/motd"
    cp -f /usr/share/burmal-dos/branding/runit-1 "$TARGET/etc/runit/1"
    chmod 755 "$TARGET/etc/runit/1"
    cp -f /usr/share/burmal-dos/branding/xbps-dpx-repositories "$TARGET/etc/xbps.d/20-burmal-channels.conf"
    sed -i "s|\${BURMAL_REPOSITORY}|$BURMAL_REPOSITORY|g" "$TARGET/etc/xbps.d/20-burmal-channels.conf"
    install -Dm644 /usr/share/burmal-dos/branding/config.jsonc "$TARGET/etc/fastfetch/config.jsonc"
    install -Dm644 /usr/share/burmal-dos/branding/config-stacked.jsonc "$TARGET/etc/fastfetch/config-stacked.jsonc"
    install -Dm644 /usr/share/burmal-dos/branding/config-compact.jsonc "$TARGET/etc/fastfetch/config-compact.jsonc"
    install -Dm644 /usr/share/burmal-dos/branding/fastfetch-logo.txt "$TARGET/usr/share/burmal-dos/fastfetch-logo.txt"
    install -Dm644 /usr/share/burmal-dos/branding/fastfetch-logo-compact.txt "$TARGET/usr/share/burmal-dos/fastfetch-logo-compact.txt"
    install -Dm755 /usr/local/bin/fastfetch "$TARGET/usr/local/bin/fastfetch"
    install -Dm644 /usr/share/burmal-dos/branding/burmal-splash-menu.png "$TARGET/usr/share/backgrounds/burmal-dos.png"
    install -Dm644 /usr/share/burmal-dos/branding/vconsole.conf "$TARGET/etc/vconsole.conf"
    install -Dm644 /usr/share/burmal-dos/gui/burmal-gui.py "$TARGET/usr/share/burmal-dos/burmal-gui.py"
    install -Dm755 /usr/share/burmal-dos/gui/burmal-gui "$TARGET/usr/local/bin/burmal-gui"
    install -Dm755 /usr/share/burmal-dos/gui/burmal-gui-session "$TARGET/usr/local/libexec/burmal-gui-session"
    install -Dm755 /usr/local/bin/dpx "$TARGET/usr/local/bin/dpx"
    install -Dm755 /usr/local/sbin/burmal-installer.sh "$TARGET/usr/local/sbin/burmal-installer.sh"
    install -Dm755 /usr/sbin/setup-b-d "$TARGET/usr/sbin/setup-b-d" 2>/dev/null || true

    if [ -d /etc/NetworkManager/system-connections ]; then
        mkdir -p "$TARGET/etc/NetworkManager/system-connections"
        cp -a /etc/NetworkManager/system-connections/. "$TARGET/etc/NetworkManager/system-connections/" 2>/dev/null || true
        chmod 700 "$TARGET/etc/NetworkManager/system-connections"
        find "$TARGET/etc/NetworkManager/system-connections" -type f -exec chmod 600 {} +
    fi

    printf 'repository=%s\n' "$BURMAL_REPOSITORY" > "$TARGET/etc/xbps.d/00-repository-main.conf"
    printf 'BURMAL_REPOSITORY=%s\n' "$BURMAL_REPOSITORY" > "$TARGET/etc/burmal-repository"
    printf 'DPX_BACKEND=xbps\n' > "$TARGET/etc/dpx/dpx.conf"
}

do_configure_target() {
    ui_status "$(ui_tr 'Configuring system')" "$(ui_tr 'Applying system settings and installing the bootloader. Please wait...')"
    log "configuring BURMAL-DOS target"

    echo "$HOSTNAME" > "$TARGET/etc/hostname"
    ROOT_UUID="$(blkid -s UUID -o value "$ROOT_PART" 2>/dev/null)"
    BOOT_UUID=""
    [[ -n "$BOOT_PART" ]] && BOOT_UUID="$(blkid -s UUID -o value "$BOOT_PART" 2>/dev/null)"
    {
        if [ -n "$ROOT_UUID" ]; then
            echo "UUID=$ROOT_UUID  /          $FS_TYPE  rw,relatime  0 1"
        else
            echo "$ROOT_PART  /          $FS_TYPE  rw,relatime  0 1"
        fi
        if [ "$BOOT_MODE" = UEFI ]; then
            if [ -n "$BOOT_UUID" ]; then
                echo "UUID=$BOOT_UUID  /boot/efi  vfat  rw,relatime  0 2"
            else
                echo "$BOOT_PART  /boot/efi  vfat  rw,relatime  0 2"
            fi
        fi
        if [ -n "$HOME_PART" ]; then
            HOME_UUID="$(blkid -s UUID -o value "$HOME_PART" 2>/dev/null)"
            HOME_FS_TYPE="$(blkid -s TYPE -o value "$HOME_PART" 2>/dev/null || echo ext4)"
            if [ -n "$HOME_UUID" ]; then
                echo "UUID=$HOME_UUID  /home  $HOME_FS_TYPE  rw,relatime  0 2"
            else
                echo "$HOME_PART  /home  $HOME_FS_TYPE  rw,relatime  0 2"
            fi
        fi
        echo "tmpfs  /tmp  tmpfs  nosuid,nodev  0 0"
    } > "$TARGET/etc/fstab"
    log "fstab written (root_uuid=$ROOT_UUID boot_uuid=$BOOT_UUID home=$HOME_PART boot_mode=$BOOT_MODE)"

    mkdir -p "$TARGET/tmp"
    printf '0\n' > "$TARGET/tmp/burmal-configure.progress"
    cat > "$TARGET/tmp/burmal-configure.sh" <<'CHROOT_EOF'
set_progress() { printf '%s\n' "$1" > /tmp/burmal-configure.progress; }
set_progress 5
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
printf '%s\n' "$TIMEZONE" > /etc/timezone

groupadd -f video
groupadd -f input
useradd -m -s /bin/bash -G wheel,video,input "$USERNAME"
groupadd -f network
usermod -aG network "$USERNAME"
printf '\n%%wheel ALL=(ALL:ALL) ALL\n' >> /etc/sudoers
set_progress 15

mkdir -p /etc/skel
cat > /etc/skel/.bashrc <<'BASHRC'
PS1='\u@\h:\w\$ '
export PS1
BASHRC
cat > /etc/skel/.bash_profile <<'BASHPROFILE'
[ -r ~/.bashrc ] && . ~/.bashrc
BASHPROFILE
if [ ! -e "/home/$USERNAME/.bashrc" ]; then
    install -m644 /etc/skel/.bashrc "/home/$USERNAME/.bashrc"
else
    grep -q 'BURMAL-DOS prompt' "/home/$USERNAME/.bashrc" || cat >> "/home/$USERNAME/.bashrc" <<'USERPROMPT'
# BURMAL-DOS prompt
case $- in *i*) PS1='\u@\h:\w\$ ' ;; esac
USERPROMPT
fi
if [ ! -e "/home/$USERNAME/.bash_profile" ]; then
    install -m644 /etc/skel/.bash_profile "/home/$USERNAME/.bash_profile"
fi
grep -q 'BURMAL-DOS profile' "/home/$USERNAME/.bash_profile" || cat >> "/home/$USERNAME/.bash_profile" <<'USERPROFILE'
# BURMAL-DOS profile
[ -r ~/.bashrc ] && . ~/.bashrc
USERPROFILE
chown "$USERNAME" "/home/$USERNAME/.bashrc" "/home/$USERNAME/.bash_profile"
if [ ! -e /root/.bashrc ]; then cat > /root/.bashrc <<'ROOTBASHRC'
PS1='\u@\h:\w# '
export PS1
ROOTBASHRC
[ -e /root/.bash_profile ] || cat > /root/.bash_profile <<'ROOTBASHPROFILE'
[ -r ~/.bashrc ] && . ~/.bashrc
ROOTBASHPROFILE
fi
if [ -e /root/.bashrc ] && ! grep -q 'BURMAL-DOS prompt' /root/.bashrc; then
    cat >> /root/.bashrc <<'ROOTPROMPT'
# BURMAL-DOS prompt
case $- in *i*) PS1='\u@\h:\w# ' ;; esac
ROOTPROMPT
fi
if [ ! -e /root/.bash_profile ]; then
    cat > /root/.bash_profile <<'ROOTBASHPROFILE'
[ -r ~/.bashrc ] && . ~/.bashrc
ROOTBASHPROFILE
elif ! grep -q 'BURMAL-DOS profile' /root/.bash_profile; then
    cat >> /root/.bash_profile <<'ROOTPROFILE'
# BURMAL-DOS profile
[ -r ~/.bashrc ] && . ~/.bashrc
ROOTPROFILE
fi

# Enable the system services in runit's default runsvdir.
mkdir -p /etc/runit/runsvdir/default
ln -sfn /etc/sv/udevd /etc/runit/runsvdir/default/udevd
ln -sfn /etc/sv/dbus /etc/runit/runsvdir/default/dbus
ln -sfn /etc/sv/NetworkManager /etc/runit/runsvdir/default/NetworkManager
if [ -d /etc/sv/spice-vdagentd ]; then
    ln -sfn /etc/sv/spice-vdagentd /etc/runit/runsvdir/default/spice-vdagentd
fi
ln -sfn /etc/sv/agetty-tty1 /etc/runit/runsvdir/default/agetty-tty1
# Load the selected console keymap before the login prompt appears. The
# keymap and getty are otherwise started concurrently by runit.
cat > /etc/sv/agetty-tty1/run <<'GETTY'
#!/bin/sh
tty=${PWD##*-}
if [ "$tty" = tty1 ] && [ -r /etc/vconsole.conf ]; then
    . /etc/vconsole.conf
    [ -n "${KEYMAP:-}" ] && /usr/bin/loadkeys "$KEYMAP" >/dev/null 2>&1 || true
    if [ -n "${FONT:-}" ] && [ -x /usr/bin/setfont ]; then
        font=$(find /usr/share/kbd/consolefonts /usr/share/consolefonts -name "${FONT}.psf*" -print -quit 2>/dev/null)
        [ -n "$font" ] && /usr/bin/setfont "$font" >/dev/null 2>&1 || true
    fi
fi
[ -r conf ] && . ./conf
if [ -x /sbin/getty ] || [ -x /bin/getty ]; then
    GETTY=getty
elif [ -x /sbin/agetty ] || [ -x /bin/agetty ]; then
    GETTY=agetty
fi
exec chpst -P ${GETTY} ${GETTY_ARGS} "$tty" "${BAUD_RATE}" "${TERM_NAME}"
GETTY
chmod 755 /etc/sv/agetty-tty1/run
set_progress 25

# Generate the selected glibc locale.
if [ -f /etc/default/libc-locales ]; then
    sed -i "/^[[:space:]]*#[[:space:]]*$LOCALE[[:space:]]/s/^[[:space:]]*#[[:space:]]*//" /etc/default/libc-locales
fi
xbps-reconfigure -f glibc-locales
printf 'LANG=%s\n' "$LOCALE" > /etc/locale.conf
mkdir -p /etc/profile.d
printf 'export LANG=%s\nexport LC_ALL=%s\n' "$LOCALE" "$LOCALE" > /etc/profile.d/locale.sh
set_progress 45

# Kernel packages normally create an initramfs in their install hooks.
# Generate one if a hook did not leave it behind.
for module_dir in /lib/modules/*; do
    [ -d "$module_dir" ] || continue
    kernel_version=${module_dir##*/}
    if ! ls /boot/initramfs-*"$kernel_version"* >/dev/null 2>&1; then
        dracut --force "/boot/initramfs-$kernel_version.img" "$kernel_version"
    fi
done
ls -la /boot
set_progress 65

{
    echo 'GRUB_DISTRIBUTOR="BURMAL-DOS"'
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3"'
    echo 'GRUB_BACKGROUND="/usr/share/backgrounds/burmal-dos.png"'
} >> /etc/default/grub

if [ "$BOOT_MODE" = UEFI ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/efi \
        --bootloader-id=BURMAL-DOS --removable --no-nvram "$DISK"
else
    grub-install --target=i386-pc "$DISK"
fi
set_progress 90
grub-mkconfig -o /boot/grub/grub.cfg
set_progress 100
CHROOT_EOF

    chmod 700 "$TARGET/tmp/burmal-configure.sh"
    run_with_progress "$(ui_tr 'Configuring system')" "$(ui_tr 'Configuring BURMAL-DOS and installing the bootloader...')" \
        "$TARGET/tmp/burmal-configure.progress" \
        chroot "$TARGET" /usr/bin/env \
            TIMEZONE="$TIMEZONE" USERNAME="$USERNAME" LOCALE="$LOCALE" DISK="$DISK" \
            BOOT_MODE="$BOOT_MODE" BOOT_PART="$BOOT_PART" HOME_PART="$HOME_PART" \
            /bin/sh -e /tmp/burmal-configure.sh
    CONFIG_STATUS=$?
    rm -f "$TARGET/tmp/burmal-configure.sh" "$TARGET/tmp/burmal-configure.progress"
    [[ $CONFIG_STATUS -eq 0 ]] || die "Failed to configure BURMAL-DOS. See $LOGFILE for details."
    printf 'root:%s\n' "$ROOT_PASS1" |
        chroot "$TARGET" /usr/bin/chpasswd -c SHA512 >>"$LOGFILE" 2>&1 ||
        die "Failed to set the root password."
    printf '%s:%s\n' "$USERNAME" "$USER_PASS1" |
        chroot "$TARGET" /usr/bin/chpasswd -c SHA512 >>"$LOGFILE" 2>&1 ||
        die "Failed to set the user password."
    ROOT_PASSWORD_STATE=$(chroot "$TARGET" passwd -S root 2>>"$LOGFILE" | awk '{print $2}')
    USER_PASSWORD_STATE=$(chroot "$TARGET" passwd -S "$USERNAME" 2>>"$LOGFILE" | awk '{print $2}')
    [[ "$ROOT_PASSWORD_STATE" == "P" ]] || die "Root password was not written to the installed system."
    [[ "$USER_PASSWORD_STATE" == "P" ]] || die "User password was not written to the installed system."
    printf 'KEYMAP=%s\nFONT=ter-c16n\n' "$KEYMAP" > "$TARGET/etc/vconsole.conf"
    mkdir -p "$TARGET/etc/runit/runsvdir/default"
    ln -sfn /etc/sv/dbus "$TARGET/etc/runit/runsvdir/default/dbus"
    ln -sfn /etc/sv/NetworkManager "$TARGET/etc/runit/runsvdir/default/NetworkManager"
}
do_finish() {
    mkdir -p "$TARGET/var/log" 2>/dev/null
    cp -f "$LOGFILE" "$TARGET/var/log/burmal-install.log" 2>/dev/null || true
    {
        echo "--- parted print $DISK ---"
        parted -s "$DISK" print 2>&1
        echo "--- ls -la /boot (target) ---"
        ls -la "$TARGET/boot" 2>&1
        echo "--- ls -la /boot/efi (target) ---"
        ls -la "$TARGET/boot/efi" 2>&1
        echo "--- /etc/fstab (target) ---"
        cat "$TARGET/etc/fstab" 2>&1
        echo "--- grub.cfg menuentry lines (target) ---"
        grep -n "menuentry\|linux.*vmlinuz\|initrd" "$TARGET/boot/grub/grub.cfg" 2>&1 | head -20
        echo "--- /lib/modules (target) ---"
        ls -la "$TARGET/lib/modules" 2>&1
    } >>"$TARGET/var/log/burmal-install.log" 2>&1

    for fs in dev proc sys; do
        umount -l "$TARGET/$fs" 2>/dev/null || true
    done
    umount -R "$TARGET" 2>/dev/null || true

    restore_installer_input
    trap - EXIT
    ui_msg "$(ui_tr 'Done')" "$(ui_tr "BURMAL-DOS is installed on $DISK")"
    log "install complete"
}

main() {
    touch "$LOGFILE"
    show_welcome
    step_language
    step_keyboard
    step_hostname
    step_timezone
    step_locale
    step_network
    step_users
    step_disk
    do_partition
    do_install_base
    do_configure_target
    do_finish
}

main "$@"
