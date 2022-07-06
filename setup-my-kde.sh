#!/bin/bash +x
#
# ATENCION: Este script esta en desarrollo, puede producir errores
# Autor: Sebastián Sanchez Baldoncini
#
#------------------[ MODIFICAR ARCHIVOS DE CONFIGURACIÓN DE PLASMA-KDE ]---------------------

# Establecer distribucion de teclado latam
text g "\n[+] Configurando distribucion de teclado\n"
$CHR "echo -e '\n[Layout]\nLayoutList=latam\nModel=acer_laptop\nUse=true' >>/home/$USR1/.config/kxkbrc"

# Deshabilitar splash
text g "\n[+] Deshabilitando pantalla de bienvenida\n"
$CHR "echo -e '[KSplash]\nEngine=none\nTheme=None' >/home/$USR1/.config/ksplashrc"

# Deshabilitar lockscreen
text g "\n[+] Deshabilitando bloqueador de pantalla\n"
$CHR "echo -e '\n[Daemon]\nAutolock=false\nLockOnResume=false' >>/home/$USR1/.config/kscreenlockerrc"

# Configurar powerdevil
text g "\n[+] Configurando opciones de energía\n"
powerfile="/home/$USR1/.config/powermanagementprofilesrc"
# Cambiar valores
$CHR "sed -i '12 s/1/0/g' $powerfile"
$CHR "sed -i '13 s/16/8/g' $powerfile"
$CHR "sed -i '28 s/16/8/g' $powerfile"
$CHR "sed -i '20 s/300/600/g' $powerfile"
$CHR "sed -i '24 s/120000/300000/g' $powerfile"
$CHR "sed -i '13 s/16/8/g' $powerfile"
# Eliminar lineas
$CHR "sed -i '3d;4d;5d;6d;7d;8d;9d;30d;31d;32d;33d' $powerfile"
# Añadir lineas
$CHR "sed -i '4 i [AC][BrightnessControl]' $powerfile"
$CHR "sed -i '5 i value=100' $powerfile"
$CHR "sed -i '8 i triggerLidActionWhenExternalMonitorPresent=true' $powerfile"
$CHR "sed -i '24 i triggerLidActionWhenExternalMonitorPresent=false' $powerfile"
$CHR "sed -i '43 i triggerLidActionWhenExternalMonitorPresent=false' $powerfile"
$CHR "sed -i '47 i suspendThenHibernate=false' $powerfile"

# Configurar numlock en el inicio
text g "\n[+] Configurando pad numerico activado en el inicio\n"
$CHR "echo -e "\n[Layout]\n[Keyboard]\nNumLock=0" >>/home/$USR1/.config/kcminputrc"

# Configurar touchpad
text g "\n[+] Configurando opciones del trackpad\n"
$CHR "echo -e "[SYNA7DB5:01 06CB:CD41 Touchpad]\nclickMethodAreas=false\nclickMethodClickfinger=true\ntapToClick=true\n" >/home/$USR1/.config/touchpadxlibinputrc"

# Configuración global plasma-kde 
# Configurar iconos
text g "\n[+] Configurando 'papirus' como tema de iconos\n"
$CHR "echo -e "\n[Icons]\nTheme=Papirus-Dark" >>/home/$USR1/.config/kdeglobals"
# Tema oscuro + borrar sin confirmacion + clic
text g "\n[+] KDE: Changing to dark theme and single click\n"
$CHR "echo -e "\n[KDE]\nLookAndFeelPackage=org.kde.breezedark.desktop\nShowDeleteCommand=false\nSingleClick=false" >>/home/$USR1/.config/kdeglobals"

# Configurar sddm
# Desactivar numlock al inicio
$CHR "sed -i '/Numlock/d' /etc/sddm.conf.d/kde_settings.conf"
# Configurar tema
$CHR "sed -i 's/McMojave/breeze/g' /etc/sddm.conf.d/kde_settings.conf"
