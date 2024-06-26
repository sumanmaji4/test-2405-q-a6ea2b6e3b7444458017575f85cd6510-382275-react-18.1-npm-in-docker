set -e

echo "Updating..."
sudo apt-get update && sudo apt-get install -y netcat
sudo service dbus start || true
sudo apt install -y libappindicator3-1 libatk-bridge2.0-0 libatspi2.0-0 libdrm2 libfontconfig1 libglib2.0-0 libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 libx11-xcb1 libxcb-dri3-0 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxtst6 xdg-utils libgbm1

echo "Installing Chrome for Selenium.."
cd /tmp
sudo rm -rf chrome-linux64* || true
wget https://storage.googleapis.com/chrome-for-testing-public/116.0.5845.96/linux64/chrome-linux64.zip
unzip -o chrome-linux64.zip
sudo rm -rf /usr/local/bin/chrome || true
sudo rm -rf /usr/bin/chrome || true
sudo ln -s /tmp/chrome-linux64/chrome /usr/local/bin/chrome
sudo ln -s /tmp/chrome-linux64/chrome /usr/bin/chrome

echo "Installing chromedriver for Selenium..."
sudo rm -rf chromedriver-linux64* || true
wget https://storage.googleapis.com/chrome-for-testing-public/116.0.5845.96/linux64/chromedriver-linux64.zip
unzip -o chromedriver-linux64.zip
sudo rm -rf /usr/local/bin/chromedriver || true
sudo rm -rf /usr/bin/chromedriver || true
sudo ln -s /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver
sudo ln -s /tmp/chromedriver-linux64/chromedriver /usr/bin/chromedriver
chromedriver --version

if nc -zv localhost 9515 2>/dev/null; then
    echo "Port 9515 is up, running the command..."
    # Your command here
else
    chromedriver --whitelisted-ips --allowed-origins='*' &
fi


