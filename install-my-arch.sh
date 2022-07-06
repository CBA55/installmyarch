#!/bin/bash +x
#
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
      TYPEFLAG=$(dialog --colors --clear --title "\Z7[ PERFIL DE INSTALACION ]\Zn" \
      --yes-button "VMWARE" \
      --no-button "NATIVE" \
      --yesno "\n Instalar paquetes y drivers para:." 7 65 \
      3>&1 1>&2 2>&3 3>&- \
      )
      [[ $? = 0 ]] && TYPEFLAG="Vmware"
      [[ $? = 1 ]] && TYPEFLAG="Native"
      EFIFLAG=$(dialog --colors --clear --backtitle "" \
      --title "\Z7[ FORMATEAR PARTICIÓN EFI ]\Zn" \
      --yesno "\nSi la partición efi se comparte con otro/s SO, elejir 'no'" 7 65 \
      3>&1 1>&2 2>&3 3>&- \
      )
      [[ $? = 0 ]] && EFIFLAG="Yes"
      [[ $? = 1 ]] && EFIFLAG="No"
      ;;
    " [*] Boot")
      autodetect parts >$PARTS
      BDISP=$(display radio "SLECCIONAR PARTICIÓN BOOT")
      BPOINT=$(display input "PUNTO DE MONTAJE" "$BPOINT")
      BSIZE=$(autodetect size_show $BDISP)
      ;;
    " [*] Efi")
      autodetect parts >$PARTS
      EDISP=$(display radio "SELECCIONAR PARTICIÓN EFI")
      ESIZE=$(autodetect size_show $EDISP)
      EPOINT=$(display input "PUNTO DE MONTAJE" "$EPOINT")
      ;;
    " [*] Root")
      RDISP=$(display radio "SELECCIONAR PARTICIÓN ROOT")
      RSIZE=$(autodetect size_show $RDISP)
      ;;
    " [*] Pass")
      declare -i i=0
      while [[ $i = 0 ]]; do
        PASS=$(display pass "CONTRASEÑA DE USUARIO ROOT" "Ingresar contraseña:")  
        PASSCHK=$(display pass "CONTRASEÑA DE USUARIO ROOT" "Confirmar contraseña:")
        display check $PASS $PASSCHK 0
      done
      ;;
    " [ ] User")
      USR1=$(display input "INGRESAR NOMBRE DE USUARIO" "$USR1" "\nDejar en blanco para omitir creación de la cuenta y directorio home\n")
      if [[ -n $USR1 ]]; then
        declare -i i=0
        while [[ $i = 0 ]]; do
          PASS1=$(display pass "CONTRASEÑA DE USUARIO" "Ingresar contraseña para el usuario $USR1:")  
          PASS1CHK=$(display pass "CONTRASEÑA DE USUARIO" "Confirmar contraseña para el usuario $USR1:")
          display check $PASS1 $PASS1CHK 1
        done
        HPOINT="$RPOINT/home"
      else
        PASS1FLAG=""; HDISP=""; HSIZE=""; HPOINT=""
      fi
      ;;
    " [ ] Home")
      if [[ -n $USR1 ]]; then
        HDISP=$(display radio "SELECCIONAR PARTICIÓN HOME")
        HSIZE=$(autodetect size_show $HDISP)
      else
       display error "Configurar nombre de usuario primero"
      fi
      ;;
    " [ ] Host")
      HOST=$(display input "INGRESAR NOMBRE DE USUARIO" "$HOST")
      ;;
    " [ ] Ntfs")
      autodetect parts >$PARTS
      MDISP=$(display radio "SELECCIONAR PARTICIÓN DE DATOS")
      MPOINT=$(display input "PUNTO DE MONTAJE" "$MPOINT")
      MSIZE=$(autodetect size_show $MDISP)
      ;;
    " [ ] Kde")
      IMPORTFILES=$(dialog --colors --clear --title "\Z7[ PERSONALIZAR PLASMA-KDE ]\Zn" \
      --yesno "\n Importar archivos de configuración." 7 65 \
      3>&1 1>&2 2>&3 3>&- \
      )
      [[ $? = 0 ]] && IMPORTFILES="Yes"
      [[ $? = 1 ]] && IMPORTFILES="No"
      IMPORTPATH=$(display input "RUTA PARA IMPORTAR ARCHIVOS" "$IMPORTPATH")
      ;;
    " [!] DONE")
      g=1
      ;;
  esac
done

# Ventana para seleccionar paquetes de los repositorios oficiales (core, extra y community)
PAC1=$(dialog --colors --clear --backtitle "INSTALADOR DE ARCHLINUX - PASO 3/5" \
--no-items \
--title "\Z7[ PAQUETES DE REPOSITORIOS OFICIALES ]\Zn" \
--nocancel \
--checklist "\nSeleccionar paquetes para instalar:" 0 0 0 $(while read line; do echo $line; done <$COM) \
3>&1 1>&2 2>&3 3>&- \
)

# Ventana para seleccionar paquetes AUR del repositorio 'multilib'
AUR1=$(dialog --colors --clear --backtitle "INSTALADOR DE ARCHLINUX - PASO 4/5" \
--no-items \
--title "\Z7[ PAQUETES AUR DE REPOSITORIO MULTILIB ]\Zn" \
--nocancel \
--checklist "\nSeleccionar paquetes:" 0 0 0 $(while read line; do echo $line; done <$AUR) \
3>&1 1>&2 2>&3 3>&- \
)

# Resumen de los parámetros configurados para la instalación
dialog --colors --clear --backtitle "INSTALADOR DE ARCHLINUX - PASO 5/5" \
--title "\Z7[ RESUMEN ]\Zn" \
--yes-label "INSTALAR" \
--no-label "REINICIAR" \
--yesno \
"\nPARAMETROS REQUERIDOS:\n
Flag | Perfil de instalacón:\Z4$TYPEFLAG\Zn | Importar configuración:\Z4$IMPORTFILES\Zn\n
Boot | Partition:\Z4$BDISP\Zn | Tamaño:\Z4$BSIZE\Zn | Montar:\Z4$BPOINT\Zn\n
 Efi | Partition:\Z4$EDISP\Zn | Tamaño:\Z4$ESIZE\Zn | Montar:\Z4$EPOINT\Zn | Formatear:\Z4$EFIFLAG\Zn\n
Root | Partición:\Z4$RDISP\Zn | Tamaño:\Z4$RSIZE\Zn | Contraseña:\Z4$PASSFLAG\Zn\n
\nPARAMETROS OPCIONALES:\n
Host | Nombre de host:\Z4$HOST\Zn\n
User | Nombre de usuario:\Z4$USR1\Zn | Contraseña de $USR1:\Z4$PASS1FLAG\Zn\n
Home | Partición:\Z4$HDISP\Zn | Tamaño:\Z4$HSIZE\Zn | Montar:\Z4$HPOINT\Zn\n
Data | Partición:\Z4$MDISP\Zn | Tamaño:\Z4$MSIZE\Zn | Montar:\Z4$MPOINT\Zn\n\n" 0 0
# Función para el botón 'REINICIAR'
restart

#------------------[ START INSTALLATION ]---------------------

# Comandos para chroot y pacman
CHR="arch-chroot $RPOINT sh -c"
INSTALL="pacman -S --color always --noconfirm"

# Nota: verificar particiones montadas en este punto

# Cuenta regresiva para formatear particiones
clockfor="[*] Formatear particiones en: "
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
[[ $EFIFLAG = "No" ]] && text y "\n[+] Omitiendo formato de la partición efi\n" 

# Si se configuró usuario, formatear la particion home
if [[ -n $USR1 ]]; then
  text g "\n[+] Formateando partición home: $HDISP\n"
  mkfs.ext4 -F /dev/$HDISP
fi

#------------------[ CHECK DIRS AND MOUNT ]---------------------

clockfor="[*] Montar particiones en: "
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
clockfor="[*] Instalar paquetes base con 'pacstrap' en: "
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
clockfor="[*] Comenzar la sesión chroot en: "
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
  text g "\n[+] Configurando nombre de host como: $HOST\n"
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

text g "\n[+] Actualizando repositorios\n"
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

text g "\n[+] Activando servicio para la administración de redes\n"
$CHR "systemctl enable NetworkManager"

text g "\n[+] Instalando bootloader (refind)\n"
$CHR "$INSTALL refind"
$CHR "refind-install"
_BPOINT=$(echo "$BPOINT" | sed 's/[/]mnt//g')
$CHR "sed -i 's/archisobasedir=arch/ro root=\/dev\/$RDISP/g' $_BPOINT/refind_linux.conf"

clockfor="[!] Instalar paquetes de repositorios oficiales en: "
reverse_clock
$CHR "$INSTALL $PAC1"

# Si la variable de usuario no está vacía, realizar lo siguiente:
if [[ -n $USR1 ]]; then
  text g "\n[+] Creando cuenta de usuario\n"
  # Crear usuario con home, agreagar a grupo primario y suplementarios, establecer zshell como shell por defecto
  $CHR "useradd -m -g users -G wheel,power,storage,input -s /bin/zsh $USR1"
  text g "\n[+] Configurando contraseña del usuario $USR1\n"
  $CHR "echo $USR1:$PASS1 | chpasswd"
  text g "\n[+] Agregando permisos de configuracion de sistema en sudoers\n"
  $CHR "sed -i '85 s/# *//' /etc/sudoers"
  text g "\n[+] Activando color de sintaxis para 'nano' (usuario $USR1)\n"
  $CHR "find /usr/share/nano/ -iname "*.nanorc" -exec echo include {} \; > /home/$USR1/.nanorc"
  $CHR "ln -s /home/$USR1/.nanorc ~/.nanorc"
   text g "\n[+] Instalando ayudante de AUR 'yay' (descargar y compilar paquetes)\n"
  $CHR "$INSTALL git"
  $CHR "git clone https://aur.archlinux.org/yay.git"
  $CHR "chown $USR1:users /yay;cd /yay;sudo -u $USR1 makepkg --noconfirm -sci"
  $CHR "rm -rf /yay"
  YAYINSTALL="sudo -u $USR1 yay -S --color always --noconfirm"
  # Permitir paru sin contraseña (temporalmente)
  #$CHR "echo -e '%wheel ALL=(ALL) NOPASSWD: /usr/bin/paru' >>/etc/sudoers"
  # OH-MY-ZSHELL + POWERLEVEL10K
  #text g "\n[+] Instalando y configurando oh-my-zshell + tema powerlevel10k\n"
  #$CHR "sudo -u $USR1 sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)""
  #$CHR "sudo -u $USR1 sh -c git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
  #$CHR "$YAYINSTALL zsh-theme-powerlevel10k-git ttf-meslo-nerd-font-powerlevel10k"
  #$CHR "sudo -u $USR1 echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc"
  # Root
  #$CHR "echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc"
  # Paquetes AUR
  clockfor="[!] Instalar paquetes AUR seleccionados en: "
  reverse_clock
  $CHR "yay -Sy"
  $CHR "$YAYINSTALL $AUR1"
else
  text g "\n[+] Activando color de sintaxis para 'nano' (usuario root)\n"
  $CHR "find /usr/share/nano/ -iname "*.nanorc" -exec echo include {} \; > ~/.nanorc"
fi

# Instalar paquetes de drivers segun perfil de instalación seleccionado
if [ $TYPEFLAG = "Native" ]; then
  clockfor="[!] Instalar drivers para perfil de instalación 'nativo' en: "
  reverse_clock
  $CHR "$INSTALL $DVRNATIVE"
  text g "\n[+] Activando autoinicio del servicio 'bluetooth'\n"
  $CHR "systemctl enable bluetooth"
else
  clockfor="[!] Instalar drivers para perfil de instalación 'vmware' en: "
  reverse_clock
  $CHR "$INSTALL $DVRVMWARE"
  text g "\n[+] Activando autoinicio del servcio de vmware 'vmtools'\n"
  $CHR "systemctl enable vmtoolsd.service"
fi

#------------------[ DESMONTAR PARTICIONES Y REINICIAR ]---------------------

  clockfor="[!] Desmontar y reiniciar en: "
  reverse_clock
  umount -R $RPOINT
  reboot