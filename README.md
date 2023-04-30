# JMRIswitches
JMRIswitches is a LUA script for Opencomputers to automate the toggling of switches in MC from a Web interface in JMRI.

# Requirements 
Minecraft 1.12.2

# Installation
**1. Add Opencomputers and Automation Mod to MC**

Download Opencomputers from here: https://www.curseforge.com/minecraft/mc-mods/opencomputers/files

Download Automation Mod .jar from here (v0.4.0-alpha.1): https://github.com/latibro/Automation-Mod/releases/tag/v0.4.0-alpha.1

**2. Download and setup JMRI**

JMRI is free software used to automate model railroads (https://www.jmri.org/), download it from here (Tested on v4.22): https://www.jmri.org/download/

After installation, Start PanelPro

Navigate to Tools, Tables - to access Turnouts and Lights

Under Tools, Select 'Start JMRI Web Server', to automatically start the web server follow https://www.jmri.org/help/en/html/web/index.shtml

Navigate to http://localhost:12080/ if using default settings to access the Web interface

**3. Setup Opencomputers and download the scripts**

Setup a standard Opencomputer

Connect world_link box from Automation Mod to the computer:

![image](https://user-images.githubusercontent.com/11053436/117896937-909f8780-b2b9-11eb-9c0f-b07d780af309.png)

Download the pastebin scripts from this github repo by pasting these commands into the Opencomputer:

	wget https://raw.githubusercontent.com/Gazer29/JMRIswitches/main/JMRIswitches.lua

	wget https://raw.githubusercontent.com/Gazer29/JMRIswitches/main/json.lua

Edit the start-up file: 'edit .shrc' and add the program to the file: 'JMRIswitches' then save and exit (cntl+s, cntl+w)

# Usage

**1. Run JMRIswitches**

Reboot Opencomputers or start using the command 'JMRIswitches'

Follow the initial configuration instructions by entering in the ip, port of the JMRI Web interface:

	If on your local machine, ip = localhost, port = 12080
	Note - If running MC and JMRI locally, the MC OpenComputers configuration file needs to allow local connections, 
		Remove from the blacklist "127.0.0.1/8". 

The program will add buttons to the Lights table on JMRI / Web interface:

	ILBuildMode = Continuously searches for any new Redstone box and adds them to the Turnout table 
	ILFindSwitches = One off BuildMode
	ILUpdateSwitches = Updates the state of each Redstone box that is in the Turnout table

Turn on BuildMode and UpdateSwitches from the Lights table before placing down a new Redstone box where you want a switch:

![image](https://user-images.githubusercontent.com/11053436/117919430-e4739600-b2e4-11eb-88f9-81fb89cd705a.png)

The Redstone_box will be added to the Turnout table, edit it in JMRI with a unique username to keep track, toggle the state of the switch to check MC is updating correctly

When finished placing Redstone boxes, turn off BuildMode to increase performance

Toggle the switches from the Turnout table as needed, have fun.
