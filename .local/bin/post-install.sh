#!/bin/bash

if [[ ! -d $HOME/.local/bin || ! -d $HOME/.local/cfg || -z $(ls -a $HOME/.local/bin) || -z $(ls -a $HOME/.local/cfg) ]]; then
	echo "Source folders missing"
	exit
fi 

# Prepare log directory various script outputs
mkdir $HOME/.local/log

# AUR helper
cd $HOME
sudo pacman -S git base-devel --noconfirm
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd $HOME
sudo rm -r yay

# Install packages
sudo pacman -S --needed - < /home/antsva/.local/cfg/pkg-explicit.pacman
yay -S --needed - < /home/antsva/.local/cfg/pkg-explicit.aur

# Litarvan theme for lightdm
if [[ $(which lightdm) && $(which lightdm-webkit2-greeter) && -d /usr/share/lightdm-webkit/themes/litarvan/ ]]; then
	sudo sed -i "s/#greeter-session=.*/greeter-session=lightdm-webkit2-greeter/" /etc/lightdm/lightdm.conf
	sudo sed -i "s/webkit_theme.*/webkit_theme = litarvan/" /etc/lightdm/lightdm-webkit2-greeter.conf
fi

# Enable networking
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
sudo systemctl enable bluetooth
sudo systemctl start bluetooth

# ACPI events
if [[ -f /etc/acpi/handler.sh ]]; then
	sudo systemctl enable acpid.service
	sudo systemctl start acpid.service
	sudo rm /etc/acpi/handler.sh
	sudo ln -s /home/antsva/.local/bin/handler.sh /etc/acpi/handler.sh
fi

# Disable internal speaker (system beep)
sudo rmmod pcspkr
echo "blacklist pcspkr" | sudo tee /etc/modprobe.d/nobeep.conf

# To change backlight with xbacklight (via acpilight package)
sudo usermod -aG video $USER

# Allow passwordless commands (e.g. sudo rfkill block bluetooth)
sudo cp $HOME/.local/cfg/rfkill /etc/sudoers.d/rfkill
sudo cp $HOME/.local/cfg/bluetooth /etc/sudoers.d/bluetooth

# Network automations
sudo ln -s /home/antsva/.local/bin/90-on-wifi.sh /etc/NetworkManager/dispatcher.d/90-on-wifi.sh && sudo chown root:root /etc/NetworkManager/dispatcher.d/90-on-wifi.sh

# Touchpad settings
sudo ln -s /home/antsva/.local/cfg/30-libinput.conf /etc/X11/xorg.conf.d/30-libinput.conf

# Force kitty to recognize font in ~/.config/fontconfig/fonts.conf
fc-cache -r

# LaTeX
# sudo ln -s /etc/fonts/conf.avail/09-texlive-fonts.conf /etc/fonts/conf.d/09-texlive-fonts.conf
# fc-cache && mkfontscale && mkfontdir

# Sandboxing
if [[ $(which firejail) ]]; then
	if [[ $(which steam) ]]; then
		sudo ln -s /usr/bin/firejail /usr/local/bin/steam-native
		sudo ln -s /usr/bin/firejail /usr/local/bin/steam
	fi

	if [[ $(which wine) ]]; then
		sudo ln -s /usr/bin/firejail /usr/local/bin/wine
	fi

	if [[ $(which firefox) ]]; then
		sudo ln -s /usr/bin/firejail /usr/local/bin/firefox
	fi

	# Fix .desktop files
	firecfg --fix
fi

# Touchpad gestures
if [[ $(which libinput-gestures) ]]; then
	sudo gpasswd -a $USER input
elif [[ $(which gebaar) ]]; then
	ln -s /home/antsva/.local/cfg/gebaard.toml /home/antsva/.config/gebaar/gebaard.toml
	sudo usermod -a -G input $USER
fi

# ssh
if [[ $(which sshd) ]]; then
	sudo systemctl enable sshd
	sudo systemctl start sshd
fi

# Printer support
if [[ $(which avahi-daemon) ]]; then
	sudo systemctl enable avahi-daemon.service
	sudo systemctl start avahi-daemon.service
fi
if [[ ! $(which nss-mdns) ]]; then
	echo "Skrivarstöd: paketet 'nss-mdns' fattas."
fi

# Battery life for laptops
if [[ $(which auto-cpufreq) ]]; then
	sudo systemctl enable auto-cpufreq
fi
if [[ $(which tlp) ]]; then
	sudo systemctl enable tlp.service
fi

# Automatic screen brightness
if [[ $(which clight) ]]; then
	sudo systemctl enable clightd.service
fi

# Jack
# https://jackaudio.org/faq/linux_rt_config.html
sudo sed -i '/End of file/ i @audio          -       rtprio          95' /etc/security/limits.conf
sudo sed -i '/End of file/ i @audio          -       memlock         unlimited' /etc/security/limits.conf