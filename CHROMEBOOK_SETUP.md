# Chromebook setup guide

This guide is for running the portable server from an external SSD on a Chromebook.

## Requirements
- Chromebook with Linux support enabled
- External SSD or USB drive
- Internet access for the first install
- Docker support inside Linux

## 1. Copy the project to the SSD
Copy the project folder to the SSD root as:

E:\palladium

## 2. Share the SSD with Linux on Chromebook
1. Open the Files app
2. Right-click the SSD
3. Select “Share with Linux”
4. Open the Linux terminal

## 3. Open the project folder
In the terminal, change into the project folder:

```bash
cd /media/YOUR_SSD/palladium
```

If the drive uses a different name, replace YOUR_SSD with the actual folder name.

## 4. Run the setup
```bash
chmod +x setup.sh install.sh
./setup.sh
./install.sh
```

## 5. Start the server
You can start the interactive menu with:

```bash
palladium
```

For a quick starter stack:

```bash
palladium stack starter
```

## 6. Keep it running
For a Chromebook, it is best to run the server in a persistent terminal session:

```bash
tmux new -s palladium
palladium
```

That keeps the app alive even if the original terminal window closes.

## 7. Verify the install
Check the service status with:

```bash
palladium status
```

If a service is not starting, inspect logs with:

```bash
palladium logs <service-name>
```

## Notes
- The project is designed to be portable, so the app data stays with the SSD.
- For best results, keep the SSD connected while the services are running.
- If Docker is missing, the setup script will prompt to install it.
