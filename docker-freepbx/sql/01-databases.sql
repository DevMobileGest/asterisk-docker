-- Create databases
CREATE DATABASE IF NOT EXISTS `asterisk`;

CREATE DATABASE IF NOT EXISTS `asteriskcdrdb`;

-- Create asterisk user with all permissions from any host
-- Note: The password should match DB_PASS in .env
CREATE USER IF NOT EXISTS 'asterisk' @ '%' IDENTIFIED BY 'asteriskpass';

GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk' @ '%';

GRANT ALL PRIVILEGES ON asteriskcdrdb.* TO 'asterisk' @ '%';

-- Also create for localhost
CREATE USER IF NOT EXISTS 'asterisk' @ 'localhost' IDENTIFIED BY 'asteriskpass';

GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk' @ 'localhost';

GRANT ALL PRIVILEGES ON asteriskcdrdb.* TO 'asterisk' @ 'localhost';

-- Apply changes immediately
FLUSH PRIVILEGES;