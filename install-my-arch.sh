#!/bin/bash +x
# Script de Instalacion desatendida de Archlinux 
# Autor: Sebastian Sanchez Baldoncini
# ----------------------------------------------

# Guardar info para mostrar en menu
OUTPUT=/tmp/output.sh.$$
PARTS=/tmp/parts.sh.$$
LAYOUTS=/tmp/layouts.sh.$$

# Guardar opcion seleccionada
INPUT=/tmp/menu.sh.$$

# Obtener path absoluto para archivos de configuración
COM=$(echo $0 | sed 's/install-my-arch.sh/com-packages.cfg/')
AUR=$(echo $0 | sed 's/install-my-arch.sh/aur-packages.cfg/')

# Borrar archivos temporales si se recive señal de interrupción (ctrl + c)
trap "rm $OUTPUT; rm $PARTS; rm $LAYOUTS; rm $INPUT; umount -R $RPOINT; exit" SIGHUP SIGINT SIGTERM

# Paquetes base
BASE="base base-devel linux linux-firmware linux-headers man man-pages"
# Paquetes para instalacion nativa o vm (nota: automatizar)
DVRVMWARE="xf86-video-vmware xf86-input-vmmouse open-vm-tools"
DVRNATIVE="xf86-video-intel pulseaudio pulseaudio-bluetooth"
# Paquetes de entorno grafico
ENV="sddm plasma-meta konsole dolphin dolphin-plugins ark"

# Funcion para 'Dialog' (GUI)
function display()
{
  case $1 in
    error)
      # Ventana de error standar
      dialog --colors --title "\Z1[ ERROR ]" \
      --ok-label RETRY --msgbox "\n\Zb\Z1[!] $2" 7 45
      ;;
    pass)
      # Ventana de configuracion de contraseña
      dialog --colors --title "\Z7[ $2 ]\Zn" \
      --ok-label NEXT --no-cancel --insecure \
      --passwordbox "\n$3" 0 0 3>&1 1>&2 2>&3 3>&-
      ;;
    check)
      # Chequear correcto ingreso de contraseña (nota: mover a nueva funcion)
      if [ -z $2 ] || [ -z $3 ]; then
        display error "La contraseña no puede quedar vacía"
      elif [ $2 != $3 ]; then
        display error "Las contraseñas no coinciden"
      else
        [[ $4 = 0 ]] && PASSFLAG="Established"; i=1
        [[ $4 = 1 ]] && PASS1FLAG="Established"; i=1
      fi
      ;;
    input)
      # Ventana para el ingreso de datos
      dialog --colors --clear \
      --title "\Z7[ $2 ]\Zn" \
      --ok-label OK \
      --nocancel \
      --inputbox "$4\nDefault:" 0 0 "$3" \
      3>&1 1>&2 2>&3 3>&- \
      ;;
    radio)
      # Ventana para seleccionar opcion
      dialog --colors --clear \
      --title "\Z7[ $2 ]\Zn" \
      --radiolist "\nUse [SPACEBAR] for Select:" 0 0 0 \
      $(while read line; do echo $line; done <$PARTS) \
      3>&1 1>&2 2>&3 3>&- \
      ;;
  esac
}

# Funcion para obtener valores varios
function autodetect()
{
	case $1 in
    dev)
      lsblk |grep -iw $2
      ;;
    devs)
      lsblk -lo NAME,SIZE,TYPE |grep -iw disk
      ;;
    parts)
      lsblk -lo NAME,SIZE,TYPE |grep -iw part
      ;;
    layout)
      lsblk -o NAME,SIZE,FSTYPE,TYPE |grep 'disk\|part'
      ;;
    layoutparts)
      fdisk -lo Device,Size,Type |grep $PDISP
      ;;
    size_show)
      lsblk -l |grep -iw $2 |awk '{print $4}' |tr "," "."
      ;;
    size_calc)
      lsblk |grep -iw $2 |awk '{print $4}' |tr -d G |tr -d M |tr "," "."
      ;;
    efi)
      EDISP=$(fdisk -l |grep EFI |awk '{print $1}' |sed 's/\/dev\///')
      ;;
    pv)
      PV=$(pvs |awk 'NR>1{print $1}' |sed -r 's/.{5}//')
      ;;
    mountothers)
      if cat /proc/mounts | grep -w "$2"; then
        text y "[*] $4\e[0m: Ya esta montado"
      elif mount /dev/$2 $3; then
        text g "[+] $4\e[0m: Montado correctamente"
      else
        text r "[!] $4\e[0m: Error montar"
        read; exit 1
      fi
      ;;
    makedirs)
      if [[ ! -d $2 ]]; then
        if mkdir -p $2; then
          text g "[+] $3\e[0m: El directorio se creó correctamente"
        else
          text r "[!] $3\e[0m: Error al crear directorio"
          read; exit 1
        fi
      else
        text y "[*] $3\e[0m: El directorio ya existe" 
      fi
      ;;
  esac
}

# Comensar de nuevo si el retorno es '1'
function restart()
{
  [[ $? -eq 1 ]] && sh $0
}

# Funcion para imprimir mensajes
function text()
{
  case $1 in
    # Negrita - Rojo
    r) echo -e "\e[91;1m$2\e[0m";;
    # Negrita - Verde
    g) echo -e "\e[92;1m$2\e[0m";;
    # Negrita - Amarillo
    y) echo -e "\e[93;1m$2\e[0m";;
    # Evitar error de argumento
    *) echo "text:No existe el argumento";;
  esac
}

# Funcion de cuenta regresiva
function reverse_clock()
{
  echo -ne "\e[94;1m"
  sleep 1
  x=5
  while [[ "$x" -ge 0 ]]; do
    echo -ne "$clockfor $x\r"
    x=$(( $x - 1 ))
    sleep 1
  done
  echo -ne "\n\e[0m"
}

#------------------[ INICIO ]---------------------

# Limpiar pantalla y ping a cloudflare
clear; text y "\n[*] Verificar conección a internet\n"
ping -c3 1.1.1.1

# Si el ping responde, buscar 'Dialog' localmente, si no está, instalarlo.
if [[ $? = 0 ]]; then
  if [[ ! $(pacman -Qs dialog shell scripts) ]]; then
    text y "\n[*] Instalando 'Dialog'\n"
    pacman --noconfirm -Sy dialog
  fi
else
  # Si el ping no responde, salir con codigo de error
  text r "\n[!] No hay conección a internet\n"; exit 1
fi

# Guardar lista de dispositivos
autodetect devs >$OUTPUT

# Ventana para seleccionar dispositivo a particionar (no puede quedar en blanco) 
while [[ -z $PDISP ]]; do
  PDISP=$(dialog --colors --clear --backtitle "INSTALACIÓN ARCHLINUX - PASO 1/5" \
  --title "\Z7[ DONDE SE VA A INSTALAR? ]\Zn" \
  --ok-label OK \
  --nocancel \
  --radiolist "\nSeleccionar con [SPACEBAR]:" 0 0 0 $(while read line; do echo $line; done <$OUTPUT) \
  3>&1 1>&2 2>&3 3>&- \
  )
  # Ejecutar cfdisk con el dispositivo seleccionado
  if [[ -n $PDISP ]]; then
    clear; cfdisk /dev/$PDISP
  fi
done

#------------------[ CONFIGURAR PARAMETROS DE LA INSTALACIÓN ]---------------------

# Apilar información para mostrar en el menú (Dispositivos y particiones)
echo -e "\nDISCOS DISPONIBLES:" >$LAYOUTS
autodetect layout >>$LAYOUTS
echo -e "\nPARTICIONES DEL DISCO SELECCIONADO:" >>$LAYOUTS
autodetect layoutparts >>$LAYOUTS
echo -e "\n[*] PARAMETROS REQUERIDOS\n[ ] PARAMETROS OPCIONALES\n\n" >>$LAYOUTS

# Parametros por defecto para la instalación
RDISP=""
HDISP=""
RPOINT="/mnt"
BPOINT="$RPOINT/boot"
EPOINT="$RPOINT/boot/efi"
HOST="Archlinux"
USR1="cbass"
HPOINT="$RPOINT/home"
MPOINT="/run/ssd"
EFIFLAG="No"
IMPORTFILES="No"
IMPORTPATH="/run/ssd/BACKUP-SYS/ARCH"

# Menú para configurar los parametros de la instalación
declare -i g=0
while [[ $g = 0 ]]; do
  dialog --clear --colors --backtitle "INSTALADOR DE ARCHLINUX - PASO 2/5" \
  --separate-widget $"\n" \
  --title "\Z7[ PARAMETROS DE LA INSTALACIÓN ]\Zn" \
  --cancel-label REINICIAR \
  --menu "$(<$LAYOUTS)" 0 0 0 \
  " [*] Flag" "Perfil de instalación:\Z4$TYPEFLAG\Zn | Formatear EFI:\Z4$EFIFLAG\Zn" \
  " [*] Boot" "Partición:\Z4$BDISP\Zn | Montar:\Z4$BPOINT\Zn" \
  " [*] Efi" "Partición:\Z4$EDISP\Zn | Montar:\Z4$EPOINT\Zn" \
  " [*] Root" "Partición:\Z4$RDISP\Zn | Tamaño:\Z4$RSIZE\Zn | Montar:\Z4$RPOINT\Zn" \
  " [*] Pass" "Contraseña de Root:\Z4$PASSFLAG\Zn" \
  " [ ] User" "Usuario:\Z4$USR1\Zn | Contraseña:\Z4$PASS1FLAG\Zn" \
  " [ ] Home" "Partición:\Z4$HDISP\Zn | Tamaño:\Z4$HSIZE\Zn | Montar:\Z4$HPOINT\Zn" \
  " [ ] Host" "Nombre Host:\Z4$HOST\Zn" \
  " [ ] Ntfs" "Partición de datos:\Z4$MDISP\Zn | Size:\Z4$MSIZE\Zn | Montar:\Z4$MPOINT\Zn" \
  " [ ] Conf" "Importar archivos conf:\Z4$IMPORTFILES\Zn | Ubicación:\Z4$IMPORTPATH\Zn" \
  " [!] DONE" "\Zb\Z6SIGUIENTE\Zn" \
  2>"${INPUT}"
  # Función para el botón 'REINICIAR'
  restart
  # Guardar selección
  menuitem=$(<"${INPUT}")
  # Continuar según la opción seleccionada
  case $menuitem in
    " [*] Flag")
      TYPEFLAG=$(dialog --colors --clear --title "\Z7[ INSTALL PROFILE ]\Zn" \
      --yes-button "VMWARE" \
      --no-button "NATIVE" \
      --yesno "\n This will install drivers and services consequently." 7 65 \
      3>&1 1>&2 2>&3 3>&- \
      )
      [[ $? = 0 ]] && TYPEFLAG="Vmware"
      [[ $? = 1 ]] && TYPEFLAG="Native"
      EFIFLAG=$(dialog --colors --clear --backtitle "" \
      --title "\Z7[ EFI FORMAT ]\Zn" \
      --yesno "\n If efi partition is shared with other/s OS, chose No" 7 65 \
      3>&1 1>&2 2>&3 3>&- \
      )
      [[ $? = 0 ]] && EFIFLAG="Yes"
      [[ $? = 1 ]] && EFIFLAG="No"
      ;;
    " [*] Boot")
      autodetect parts >$PARTS
      BDISP=$(display radio "SELECT BOOT DEVICE")
      BPOINT=$(display input "BOOT MOUNT POINT" "$BPOINT")
      BSIZE=$(autodetect size_show $BDISP)
      ;;
    " [*] Efi")
      autodetect parts >$PARTS
      EDISP=$(display radio "SELECT EFI DEVICE")
      ESIZE=$(autodetect size_show $EDISP)
      EPOINT=$(display input "EFI MOUNT POINT" "$EPOINT")
      ;;
    " [*] Root")
      RDISP=$(display radio "SELECT ROOT PARTITION")
      RSIZE=$(autodetect size_show $RDISP)
      ;;
    " [*] Pass")
      declare -i i=0
      while [[ $i = 0 ]]; do
        PASS=$(display pass "ROOT USER PASSWORD" "Enter ROOT password:")  
        PASSCHK=$(display pass "ROOT USER PASSWORD" "Retype ROOT password:")
        display check $PASS $PASSCHK 0
      done
      ;;
    " [ ] User")
      USR1=$(display input "ENTER USER NAME" "$USR1" "\nEmpty chain will skip user account and home dir creation\n")
      if [[ -n $USR1 ]]; then
        declare -i i=0
        while [[ $i = 0 ]]; do
          PASS1=$(display pass "USER PASSWORD" "Enter $USR1 password:")  
          PASS1CHK=$(display pass "USER PASSWORD" "Retype $USR1 password:")
          display check $PASS1 $PASS1CHK 1
        done
        HPOINT="$RPOINT/home"
      else
        PASS1FLAG=""; HDISP=""; HSIZE=""; HPOINT=""
      fi
      ;;
    " [ ] Home")
      if [[ -n $USR1 ]]; then
        HDISP=$(display radio "SELECT HOME PARTITION")
        HSIZE=$(autodetect size_show $HDISP)
      else
       display error "Please set USER first"
      fi
      ;;
    " [ ] Host")
      HOST=$(display input "ENTER HOSTNAME" "$HOST")
      ;;
    " [ ] Ntfs")
      autodetect parts >$PARTS
      MDISP=$(display radio "SELECT DATA PARTITION")
      MPOINT=$(display input "DATA MOUNT POINT" "$MPOINT")
      MSIZE=$(autodetect size_show $MDISP)
      ;;
    " [ ] Kde")
      IMPORTFILES=$(dialog --colors --clear --title "\Z7[ CUSTOMIZE KDE ]\Zn" \
      --yesno "\n This will import custom files." 7 65 \
      3>&1 1>&2 2>&3 3>&- \
      )
      [[ $? = 0 ]] && IMPORTFILES="Yes"
      [[ $? = 1 ]] && IMPORTFILES="No"
      IMPORTPATH=$(display input "IMPORT PATH" "$IMPORTPATH")
      ;;
    " [!] DONE")
      g=1
      ;;
  esac
done

# Ventana para seleccionar paquetes de los repositorios oficiales (core, extra y community)
PAC1=$(dialog --colors --clear --backtitle "INSTALADOR DE ARCHLINUX - PASO 3/5" \
--no-items \
--title "\Z7[ COMMUNITY PACKAGES ]\Zn" \
--nocancel \
--checklist "\nSelect packages:" 0 0 0 $(while read line; do echo $line; done <$COM) \
3>&1 1>&2 2>&3 3>&- \
)

# Ventana para seleccionar paquetes AUR del repositorio 'multilib'
AUR1=$(dialog --colors --clear --backtitle "INSTALADOR DE ARCHLINUX - PASO 4/5" \
--no-items \
--title "\Z7[ AUR PACKAGES ]\Zn" \
--nocancel \
--checklist "\nSelect packages:" 0 0 0 $(while read line; do echo $line; done <$AUR) \
3>&1 1>&2 2>&3 3>&- \
)

# Settings Resume
dialog --colors --clear --backtitle "INSTALADOR DE ARCHLINUX - PASO 5/5" \
--title "\Z7[ RESUMEN ]\Zn" \
--yes-label "INSTALAR" \
--no-label "REINICIAR" \
--yesno \
"\nPARAMETROS REQUERIDOS:\n
Flag | Install Profile:\Z4$TYPEFLAG\Zn | Import Custom Config:\Z4$IMPORTFILES\Zn\n
Boot | Partition:\Z4$BDISP\Zn | Size:\Z4$BSIZE\Zn | Mount:\Z4$BPOINT\Zn\n
 Efi | Partition:\Z4$EDISP\Zn | Size:\Z4$ESIZE\Zn | Mount:\Z4$EPOINT\Zn | Format:\Z4$EFIFLAG\Zn\n
Root | Root Partition:\Z4$RDISP\Zn | Size:\Z4$RSIZE\Zn | Root pass:\Z4$PASSFLAG\Zn\n
\nPARAMETROS OPCIONALES:\n
Host | Hostname:\Z4$HOST\Zn\n
User | Username:\Z4$USR1\Zn | $USR1 pass:\Z4$PASS1FLAG\Zn\n
Home | Home Partition:\Z4$HDISP\Zn | Size:\Z4$HSIZE\Zn | Mount:\Z4$HPOINT\Zn\n
Data | Data Partition:\Z4$MDISP\Zn | Size:\Z4$MSIZE\Zn | Mount:\Z4$MPOINT\Zn\n\n" 0 0
# Función para el botón 'REINICIAR'
restart

#------------------[ START INSTALLATION ]---------------------

# Comandos para chroot y pacman
CHR="arch-chroot $RPOINT sh -c"
INSTALL="pacman -S --color always --noconfirm"

# Nota: verificar particiones montadas en este punto

# Cuenta regresiva para formatear particiones
clockfor="[*] Voy a formatear las particiones"
reverse_clock

# Formatear partición root
text g "\n[+] Formateando partición root: $RDISP\n"
mkfs.ext4 -F /dev/$RDISP

# Formatear partición boot y etiquetar como 'arch' (necesario para el bootloader)
text g "\n[+] Formateando partición boot: $BDISP \n"
mkfs.ext4 -F /dev/$BDISP
text g "\n[+] Etiquetando partición boot como 'arch'\n"
tune2fs -L arch /dev/$BDISP

# Formatear la partición efi (o continuar sin formatear)
[[ $EFIFLAG = "Yes" ]] && text g "\n[+] Formateando partición efi: $EDISP\n" && mkfs.vfat -F 32 /dev/$EDISP
[[ $EFIFLAG = "No" ]] && text y "\n[+] La partición efi NO se formateará\n" 

# Si se configuró usuario, formatear la particion home
if [[ -n $USR1 ]]; then
  text g "\n[+] Formateando partición home: $HDISP\n"
  mkfs.ext4 -F /dev/$HDISP
fi

#------------------[ CHECK DIRS AND MOUNT ]---------------------

clockfor="[*] Motando particiones"
reverse_clock

# Crear directorio y montar partición root
autodetect makedirs "$RPOINT" "Root"
autodetect mountothers "$RDISP" "$RPOINT" "Root"

# Crear directorio y montar partición boot
autodetect makedirs "$BPOINT" "Boot"
autodetect mountothers "$BDISP" "$BPOINT" "Boot"

# Crear directorio y montar partición efi
autodetect makedirs "$EPOINT" "Efi"
autodetect mountothers "$EDISP" "$EPOINT" "Efi"

# Si se configuró usuario, crear directorio y montar partición home
if [[ -n $USR1 ]]; then
 autodetect makedirs "$HPOINT" "home"
 autodetect mountothers "$HDISP" "$HPOINT" "home"
fi

#------------------[ INSTALACIÓN DE PAQUETES BASE + FSTAB ]---------------------

# Cuenta regresiva para instalar paquetes base
clockfor="[*] Comienza la instalación de los paquetes base"
reverse_clock

# Instalar paquetes base en punto de montaje elegido para la raiz
pacstrap $RPOINT $BASE 

# Generar archivo fstab a partir de los puntos de montaje seleccionados
text g "\n[+] Actualizando archivo fstab\n"
genfstab -U $RPOINT >> $RPOINT/etc/fstab

# Si se configuró particion de datos, agregarla al final del archivo fstab
[[ -n $MDISP ]] && echo "UUID=$(lsblk -lo NAME,UUID |grep -w $MDISP |awk '{print $2}') $MPOINT ntfs-3g rw,users,umask=0022,uid=1000,gid=100 0 0" >> $RPOINT/etc/fstab

#------------------[ INICIO DE SESION CHROOT ]---------------------

# Cuenta regresiva para iniciar la sesion chroot
clockfor="[*] Comenzando la sesión chroot en $RPOINT"
reverse_clock

text g "\n[+] Configurando zona horaria\n"
$CHR "ln -sf /usr/share/zoneinfo/America/Argentina/Buenos_Aires /etc/localtime"

text g "\n[+] Generando archivo /etc/adjtime\n"
$CHR "hwclock --systohc"

text g "\n[+] Configurando lenguaje español/Argentina\n"
$CHR "sed -i '/es_AR/s/^#//g' /etc/locale.gen"

text g "\n[+] Generando locale\n"
$CHR "locale-gen"
$CHR "echo LANG=es_AR.UTF-8 > /etc/locale.conf"

text g "\n[+] Configurando teclado latam (tty)\n"
$CHR "echo KEYMAP=la-latin1 >> /etc/vconsole.conf"

# Si se configuro nombre de host, guardar en /etc/hostname
if [[ -n $HOST ]]; then
  text g "\n[+] Setting hostname: $HOST\n"
  $CHR "echo $HOST > /etc/hostname"
fi

text g "\n[+] Creando imagen linux\n"
$CHR "mkinitcpio -p linux"

text g "\n[+] Configurando contraseña para root\n"
$CHR "echo root:$PASS | chpasswd"

text g "\n[+] Activando repositorio 'multilib'\n"
$CHR "sed -i '93,94 s/# *//' /etc/pacman.conf"

text g "\n[+] Configurando tiempo de espera para matar servicio\n"
$CHR "sed -i '44,45 s/# *//' /etc/systemd/system.conf"
$CHR "sed -i 's/90s/9s/g' /etc/systemd/system.conf"

text g "\n[+] Activando el cortafuegos con la configuración por defecto\n"
$CHR "cp /etc/iptables/simple_firewall.rules /etc/iptables/iptables.rules"
$CHR "systemctl enable iptables"

text g "\n[+] Actualizando base de repositorios\n"
$CHR "pacman -Sy"

text g "\n[+] Instalando paquetes 'xorg'\n"
$CHR "$INSTALL xorg"

text g "\n[+] Instalando zshell y zsh-completions\n"
$CHR "$INSTALL zsh zsh-completions"
text g "\n[+] Cambiando shell de root a /bin/zsh"
$CHR "chsh -s /bin/zsh"

text g "\n[+] Instalando paquetes de entorno gráfico\n"
$CHR "$INSTALL $ENV"

text g "\n[+] Activando servicio de SDDM\n"
$CHR "systemctl enable sddm"

text g "\n[+] Activando servicio para administración de redes\n"
$CHR "systemctl enable NetworkManager"

text g "\n[+] Instalando bootloader (refind)\n"
$CHR "$INSTALL refind"
$CHR "refind-install"
_BPOINT=$(echo "$BPOINT" | sed 's/[/]mnt//g')
$CHR "sed -i 's/archisobasedir=arch/ro root=\/dev\/$RDISP/g' $_BPOINT/refind_linux.conf"

clockfor="[!] Installing community packages selected... "
reverse_clock
$CHR "$INSTALL $PAC1"

# User account
if [[ -n $USR1 ]]; then
  text g "\n[+] Creating user $USR1 with common groups\n"
  $CHR "useradd -m -g users -G wheel,power,storage,input -s /bin/zsh $USR1"
  text g "\n[+] Setting password for $USR1\n"
  $CHR "echo $USR1:$PASS1 | chpasswd"
  text g "\n[+] Setting basic config for Sudo\n"
  $CHR "sed -i '85 s/# *//' /etc/sudoers"
  text g "\n[+] Activating syntax highlighting for nano\n"
  $CHR "find /usr/share/nano/ -iname "*.nanorc" -exec echo include {} \; > /home/$USR1/.nanorc"
  $CHR "ln -s /home/$USR1/.nanorc ~/.nanorc"
  # AUR Helper 'YAY'
  text g "\n[+] Installing AUR helper YAY\n"
  $CHR "$INSTALL git"
  $CHR "git clone https://aur.archlinux.org/yay.git"
  $CHR "chown $USR1:users /yay;cd /yay;sudo -u $USR1 makepkg --noconfirm -sci"
  $CHR "rm -rf /yay"
  YAYINSTALL="sudo -u $USR1 yay -S --color always --noconfirm"
  # Allow PARU without pass (temporary)
  #$CHR "echo -e '%wheel ALL=(ALL) NOPASSWD: /usr/bin/paru' >>/etc/sudoers"
  # OH-MY-ZSHELL + POWERLEVEL10K
  #text g "\n[+] Installing and configure oh-my-zshell + powerlevel10k theme\n"
  #$CHR "sudo -u $USR1 sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)""
  #$CHR "sudo -u $USR1 sh -c git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
  #$CHR "$YAYINSTALL zsh-theme-powerlevel10k-git ttf-meslo-nerd-font-powerlevel10k"
  #$CHR "sudo -u $USR1 echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc"
  # Root
  #$CHR "echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc"
  # AUR packages
  clockfor="[!] Installing AUR packages\n"
  reverse_clock
  $CHR "yay -Sy"
  $CHR "$YAYINSTALL $AUR1"
else
  text g "\n[+] Activating syntax highlighting for nano\n"
  $CHR "find /usr/share/nano/ -iname "*.nanorc" -exec echo include {} \; > ~/.nanorc"
fi

# Install drivers packages
if [ $TYPEFLAG = "Native" ]; then
  clockfor="[!] Installing drivers for Native profile... "
  reverse_clock
  $CHR "$INSTALL $DVRNATIVE"
  text g "\n[+] Enable Bluetooth service\n"
  $CHR "systemctl enable bluetooth"
else
  clockfor="[!] Installing drivers for Vmware profile... "
  reverse_clock
  $CHR "$INSTALL $DVRVMWARE"
  text g "\n[+] Enable vmtool service\n"
  $CHR "systemctl enable vmtoolsd.service"
fi

#------------------[ UMOUNT AND REBOOT ]---------------------

  clockfor="[!] Desmontar y reiniciar en... "
  reverse_clock
  umount -R $RPOINT
  reboot

# If temp files found, delete
#[ -f $OUTPUT ] && rm $OUTPUT
#[ -f $INPUT ] && rm $INPUT
