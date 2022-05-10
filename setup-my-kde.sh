#------------------[ MODIFY KDE FILES ]---------------------

# Setup keyboard layout
text g "\n[+] Keyboard: Setting latam layout\n"
$CHR "echo -e '\n[Layout]\nLayoutList=latam\nModel=acer_laptop\nUse=true' >>/home/$USR1/.config/kxkbrc"

# Disable splash
text g "\n[+] Diabling ksplash\n"
$CHR "echo -e '[KSplash]\nEngine=none\nTheme=None' >/home/$USR1/.config/ksplashrc"

# Disable screen locker
text g "\n[+] Disabling screen locker\n"
$CHR "echo -e '\n[Daemon]\nAutolock=false\nLockOnResume=false' >>/home/$USR1/.config/kscreenlockerrc"

# Setup powerdevil settings
text g "\n[+] Configuring energy options\n"
powerfile="/home/$USR1/.config/powermanagementprofilesrc"
## Change values
$CHR "sed -i '12 s/1/0/g' $powerfile"
$CHR "sed -i '13 s/16/8/g' $powerfile"
$CHR "sed -i '28 s/16/8/g' $powerfile"
$CHR "sed -i '20 s/300/600/g' $powerfile"
$CHR "sed -i '24 s/120000/300000/g' $powerfile"
$CHR "sed -i '13 s/16/8/g' $powerfile"
## Delete lines
$CHR "sed -i '3d;4d;5d;6d;7d;8d;9d;30d;31d;32d;33d' $powerfile"
## Add lines
$CHR "sed -i '4 i [AC][BrightnessControl]' $powerfile"
$CHR "sed -i '5 i value=100' $powerfile"
$CHR "sed -i '8 i triggerLidActionWhenExternalMonitorPresent=true' $powerfile"
$CHR "sed -i '24 i triggerLidActionWhenExternalMonitorPresent=false' $powerfile"
$CHR "sed -i '43 i triggerLidActionWhenExternalMonitorPresent=false' $powerfile"
$CHR "sed -i '47 i suspendThenHibernate=false' $powerfile"

# Set numlock on startup
text g "\n[+] Setting numlock on startup\n"
$CHR "echo -e "\n[Layout]\n[Keyboard]\nNumLock=0" >>/home/$USR1/.config/kcminputrc"

# Setup touchpad buttons
text g "\n[+] Setting touchpad options\n"
$CHR "echo -e "[SYNA7DB5:01 06CB:CD41 Touchpad]\nclickMethodAreas=false\nclickMethodClickfinger=true\ntapToClick=true\n" >/home/$USR1/.config/touchpadxlibinputrc"

# Setup kde-globals
## Icons
text g "\n[+] KDE: Setting papirus icons theme\n"
$CHR "echo -e "\n[Icons]\nTheme=Papirus-Dark" >>/home/$USR1/.config/kdeglobals"
## Dark theme + delete without confikrm + singleclick
text g "\n[+] KDE: Changing to dark theme and single click\n"
$CHR "echo -e "\n[KDE]\nLookAndFeelPackage=org.kde.breezedark.desktop\nShowDeleteCommand=false\nSingleClick=false" >>/home/$USR1/.config/kdeglobals"

# Setup SDDM
## Disable numlock at startup
$CHR "sed -i '/Numlock/d' /etc/sddm.conf.d/kde_settings.conf"
## Change sddm default theme
$CHR "sed -i 's/McMojave/breeze/g' /etc/sddm.conf.d/kde_settings.conf"
