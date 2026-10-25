#!/data/data/com.termux/files/usr/bin/bash
set -e
pkg update -y
pkg install -y git openssh
echo "Project folder: $(pwd)"
echo "1) Extract FPS_Zombie_Termux.zip"
echo "2) cd FPS_Zombie_Termux"
echo "3) git init"
echo "4) git branch -M main"
echo "5) git add . && git commit -m 'Initial FPS Zombie Survival project'"
echo "6) git remote add origin https://github.com/USERNAME/REPOSITORY.git"
echo "7) git push -u origin main"
echo "Replace USERNAME/REPOSITORY with your GitHub repository."
