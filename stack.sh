#!/bin/bash

## Script to install webserver and application and server.
LOG=/tmp/stack.log 
rm -f $LOG 

## COlor Variables
R="\e[1;31m"
G="\e[1;32m"
Y="\e[1;33m"
N="\e[0m"

## 
TOMCAT_USER=studentapp
TOMCAT_VERSION="9.0.12"
TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
APP_URL='https://github.com/citb32/project-setup/raw/master/student.war'
TOMCAT_DIR="/home/$TOMCAT_USER/apache-tomcat-${TOMCAT_VERSION}"
CONTEXT='<Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource" maxTotal="100" maxIdle="30" maxWaitMillis="10000" username="student" password="student1" driverClassName="com.mysql.jdbc.Driver" url="jdbc:mysql://node:3306/studentapp"/>'
JDBC_URL="https://github.com/citb32/project-setup/raw/master/mysql-connector-java-5.1.47.jar"


Error() {
    echo -e "${R}${1}${N}"
    exit $2node
}

Info() {
    echo -e -n "$1 "
}

Stat() {
    if [ "$1"  = SKIP ]; then 
        echo -e "-- ${Y}SKIPPING${N}"
    elif [ $1 -eq 0 ]; then 
        echo -e "-- ${G}SUCCESS${N}"
    else 
        echo -e "-- ${R}FAILURE${N}"
        exit 1
    fi
}

LogS() {
    case $1 in 
        Head) 
            echo -e "\n----------------------------------------------------------------------" &>>$LOG
            echo -e "                             $2                                       " &>>$LOG
            echo -e "----------------------------------------------------------------------" &>>$LOG
            ;;
        Tail) 
            echo -e "----------------------------------------------------------------------\n" &>>$LOG
            ;;
    esac
}

Run() {
    Info "$1"
    LogS Head "$2"
    $2 &>>$LOG
    Stat $?
    LogS Tail
}

Head() {
    echo -e "\n\t\e[1;4;36m$1$N"
}

Skip() {
    Info "$1"
    LogS Head "$2"
    Stat SKIP
    LogS Tail
}
## Check whether the script executed as root user or normal user.

ID=$(id -u)
if [ "$ID" -ne 0 ]; then 
    Error "You should be a root user to run this script!!" 2
fi


Head "WEBSERVER SETUP"
Run "Installing HTTPD Server" "yum install httpd -y"  
Run "Setting up Reverse proxy" "curl -f -s https://raw.githubusercontent.com/citb32/project-setup/master/web-proxy.conf -o  /etc/httpd/conf.d/studentapp.conf"
Run "Setting Up Index File" "curl -f -s https://raw.githubusercontent.com/citb32/project-setup/master/httpd-index.html -o /var/www/html/index.html"
systemctl enable httpd &>/dev/null
Run "Start Web Service" "systemctl start httpd"

Head "APPLICATION SETUP"
Run "Installing Java" "yum install java -y"  
id $TOMCAT_USER &>/dev/null
if [ $? -eq 0 ] ; then 
    Skip "Creating Application User"
else    
    Run "Creating Application User" "useradd $TOMCAT_USER"
fi
Info "Downloading Tomcat"
LogS Head "$2" 
su - $TOMCAT_USER -c "wget -O- $TOMCAT_URL | tar -xz" &>>$LOG
Stat $?
LogS Tail
Info "Downloading Student Application"
LogS Head "$2" 
su - $TOMCAT_USER -c "rm -rf  $TOMCAT_DIR/webapps/*" &>>$LOG
su - $TOMCAT_USER -c "wget $APP_URL -O $TOMCAT_DIR/webapps/student.war" &>>$LOG
Stat $?
LogS Tail

Info "Downloading JDBC Jar"
LogS Head "$2" 
su - $TOMCAT_USER -c "wget $JDBC_URL -O $TOMCAT_DIR/lib/mariadb.jar" &>>$LOG
Stat $?
LogS Tail

Info "Configurring Tomcat"
LogS Head "$2" 
sed -i -e "/TestDB/ d" -e "$ i $CONTEXT" $TOMCAT_DIR/conf/context.xml &>>$LOG
wget https://raw.githubusercontent.com/citb32/project-setup/master/tomcat-init -O /etc/init.d/tomcat &>>$LOG
chmod ugo+x /etc/init.d/tomcat
systemctl daemon-reload &>>$LOG
Stat $?
LogS Tail

systemctl enable tomcat &>/dev/null
Run "Start Tomcat Service" "systemctl start tomcat"
