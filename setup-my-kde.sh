#!/bin/bash +x
# Under develope, don't use it
USR1=cbass

 # Setup keyboard layout
#echo -e "\n[Layout]\nLayoutList=latam\nModel=acer_laptop\nUse=true" >>/home/$USR1/.config/kxkbrc

# Disable splash
#echo -e "[KSplash]\nEngine=none\nTheme=None" >/home/$USR1/.config/ksplashrc

# Disable screen locker
#echo -e "\n[Daemon]\nAutolock=false\nLockOnResume=false" >>/home/$USR1/.config/kscreenlockerrc

# Setup powerdevil settings
powerfile="/home/$USR1/.config/powermanagementprofilesrc"
## Change values
sed -i '12 s/1/0/g' $powerfile
sed -i '13 s/16/8/g' $powerfile
sed -i '28 s/16/8/g' $powerfile
sed -i '20 s/300/600/g' $powerfile
sed -i '24 s/120000/300000/g' $powerfile
sed -i '13 s/16/8/g' $powerfile
## Delete lines
sed -i '3d;4d;5d;6d;7d;8d;9d;30d;31d;32d;33d' $powerfile
## Add lines
sed -i '4 i [AC][BrightnessControl]' $powerfile
sed -i '5 i value=100' $powerfile
sed -i '8 i triggerLidActionWhenExternalMonitorPresent=true' $powerfile
sed -i '24 i triggerLidActionWhenExternalMonitorPresent=false' $powerfile
sed -i '43 i triggerLidActionWhenExternalMonitorPresent=false' $powerfile
sed -i '47 i suspendThenHibernate=false' $powerfile

# Set numlock on startup
echo -e "\n[Layout]\n[Keyboard]\nNumLock=0" >>/home/$USR1/.config/kcminputrc

# Setup touchpad buttons
echo -e "[SYNA7DB5:01 06CB:CD41 Touchpad]\nclickMethodAreas=false\nclickMethodClickfinger=true\ntapToClick=true\n" >/home/$USR1/.config/touchpadxlibinputrc
